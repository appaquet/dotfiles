{ pkgs }:

let
  # Reader shell and shared feedback assets are immutable runtime data served
  # under the server's reserved namespace, never regenerated per review.
  assets = pkgs.runCommand "show-me-assets" { } ''
    mkdir -p $out
    cp ${./show-me-docs.html} $out/docs.html
    cp ${./show-me-docs.js} $out/docs.js
    cp ${./show-me-docs.css} $out/docs.css
    cp ${./show-me-feedback.js} $out/feedback.js
    cp ${./show-me-feedback.css} $out/feedback.css
    cp ${./show-me-feedback-auto.js} $out/feedback-auto.js
  '';
in
pkgs.writeShellApplication {
  name = "show-me-serve";

  runtimeInputs = with pkgs; [
    bun
    coreutils
    gnugrep
    cloudflared
  ];

  text = ''
    main() {
      public=""
      help=""

      # Options precede the optional directory, as they always have. The
      # directory itself defaults to the current one.
      while [ "$#" -gt 0 ]; do
        case "$1" in
          -h | --help)
            help="1"
            shift
            ;;
          --public)
            public="1"
            shift
            ;;
          --)
            shift
            break
            ;;
          -*)
            echo "Unknown option '$1'." >&2
            usage_hint
            exit 2
            ;;
          *)
            break
            ;;
        esac
      done

      if [ -n "$help" ]; then
        usage
        exit 0
      fi

      if [ "$#" -gt 1 ]; then
        echo "Too many arguments." >&2
        usage_hint
        exit 2
      fi

      directory="''${1-.}"
      if [ ! -d "$directory" ]; then
        echo "Cannot serve '$directory': not an existing directory." >&2
        exit 1
      fi

      root=$(cd "$directory" && pwd -P)
      cd "$root"
      host=$(uname -n | tr '[:upper:]' '[:lower:]' | sed 's/\.local//')

      port=""
      server_pid=""
      tunnel_pid=""
      tunnel_url=""

      work_dir=$(mktemp -d)
      server_log="$work_dir/server.log"
      tunnel_log="$work_dir/cloudflared.log"

      trap cleanup EXIT
      trap 'exit 130' INT
      trap 'exit 143' TERM

      start_server
      echo "Serving $root internally at http://$host.n3x.net:$port/"

      if [ -n "$public" ]; then
        start_tunnel

        if [ -n "$tunnel_url" ]; then
          echo "Serving $root publicly at $tunnel_url"
          echo "The public URL may take a moment to be reachable."
        else
          echo "Could not get a public tunnel URL; serving internally only." >&2
          echo "Last cloudflared output:" >&2
          tail -n 10 "$tunnel_log" >&2 || true
        fi
      fi

      await_children
    }

    usage() {
      printf '%s\n\n' 'Usage: show-me-serve [--public] [directory]'
      printf '%s\n' 'Serve a directory over HTTP and print its internal URL. The directory defaults to the current one.'
      printf '\n'
      printf '%s\n' 'Each request chooses its mode from the path:'
      printf '%s\n' '  / and other directories  generated file index'
      printf '%s\n' '  ordinary files           served unchanged with their own content type'
      printf '%s\n' '  *.md and *.markdown      document reader with a docs tree and comments'
      printf '\n'
      printf '%s\n' 'Options:'
      printf '%s\n' '  --public    also open an anonymous cloudflared quick tunnel for sharing'
      printf '%s\n' '  -h, --help  print this help and exit'
      printf '\n'
      printf '%s\n' 'The command picks a free port and serves every reachable file below the directory' 'without authentication, so choose the narrowest directory that works. File edits' 'appear on the next request.'
    }

    usage_hint() {
      echo "Usage: show-me-serve [--public] [directory]. Run 'show-me-serve --help' for details." >&2
    }

    # Starts the show-me server on a free random port, retrying the pick-and-start
    # sequence because the port can be taken between the probe and the bind.
    start_server() {
      local attempt

      for attempt in 1 2 3 4 5; do
        port=$(shuf -i 10000-65535 -n 1)
        if port_is_listening "$port"; then
          continue
        fi

        bun ${./show-me-serve.ts} --root "$root" --port "$port" --assets ${assets} >"$server_log" 2>&1 &
        server_pid=$!

        if wait_for_port "$port"; then
          return 0
        fi

        echo "The show-me server did not start on port $port (attempt $attempt)." >&2
        stop_children
      done

      echo "Could not start the show-me server in $root after 5 attempts." >&2
      tail -n 10 "$server_log" >&2 || true
      exit 1
    }

    # Starts cloudflared and waits for the quick tunnel hostname. A missing URL is
    # not fatal: the HTTP server keeps serving internally.
    start_tunnel() {
      cloudflared tunnel --url "http://localhost:$port" --no-autoupdate >"$tunnel_log" 2>&1 &
      tunnel_pid=$!

      for _ in $(seq 1 120); do
        if tunnel_url=$(grep -m1 -ohE 'https://[a-z0-9-]+\.trycloudflare\.com' "$tunnel_log" 2>/dev/null); then
          return 0
        fi

        if ! kill -0 "$tunnel_pid" 2>/dev/null; then
          break
        fi

        sleep 0.5
      done

      tunnel_url=""

      # A tunnel that exited without a URL is not supervised: the HTTP server keeps
      # serving internally instead of the whole command stopping.
      if ! kill -0 "$tunnel_pid" 2>/dev/null; then
        wait "$tunnel_pid" 2>/dev/null || true
        tunnel_pid=""
      fi
    }

    # cloudflared reports the URL before the tunnel is connected, so the public URL
    # is reported as printed rather than probed for reachability.
    await_children() {
      if [ -z "$tunnel_pid" ]; then
        wait "$server_pid" || true
        echo "The show-me server stopped." >&2
        exit 1
      fi

      wait -n "$server_pid" "$tunnel_pid" || true

      if kill -0 "$server_pid" 2>/dev/null; then
        echo "cloudflared stopped; stopping the HTTP server." >&2
        tail -n 10 "$tunnel_log" >&2 || true
      else
        echo "The show-me server stopped; stopping the tunnel." >&2
      fi

      exit 1
    }

    stop_children() {
      if [ -n "$tunnel_pid" ]; then
        kill "$tunnel_pid" 2>/dev/null || true
        wait "$tunnel_pid" 2>/dev/null || true
        tunnel_pid=""
      fi

      if [ -n "$server_pid" ]; then
        kill "$server_pid" 2>/dev/null || true
        wait "$server_pid" 2>/dev/null || true
        server_pid=""
      fi
    }

    # Stops both children and removes the temporary log directory. It runs from the
    # EXIT trap, so it has no direct call site.
    # shellcheck disable=SC2329
    cleanup() {
      stop_children
      rm -rf "$work_dir"
    }

    port_is_listening() {
      (exec 3<>"/dev/tcp/127.0.0.1/$1") 2>/dev/null
    }

    wait_for_port() {
      for _ in $(seq 1 40); do
        if port_is_listening "$1"; then
          return 0
        fi

        if [ -n "$server_pid" ] && ! kill -0 "$server_pid" 2>/dev/null; then
          return 1
        fi

        sleep 0.25
      done

      return 1
    }

    main "$@"
  '';
}
