{ pkgs }:

pkgs.writeShellApplication {
  name = "agentic-show-me-serve";

  runtimeInputs = with pkgs; [
    coreutils
    gnugrep
    simple-http-server
    cloudflared
  ];

  text = ''
    main() {
      public=""
      if [ "$#" -gt 0 ] && [ "$1" = "--public" ]; then
        public="1"
        shift
      fi

      if [ "$#" -ne 1 ]; then
        echo "Usage: agentic-show-me-serve [--public] <directory>" >&2
        exit 2
      fi

      if [ ! -d "$1" ]; then
        echo "Cannot serve '$1': not an existing directory." >&2
        exit 1
      fi

      root=$(cd "$1" && pwd -P)
      cd "$root"
      host=$(uname -n | tr '[:upper:]' '[:lower:]' | sed 's/\.local//')

      port=""
      server_pid=""
      tunnel_pid=""
      tunnel_url=""

      work_dir=$(mktemp -d)
      server_log="$work_dir/simple-http-server.log"
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

    # Starts simple-http-server on a free random port, retrying the pick-and-start
    # sequence because the port can be taken between the probe and the bind.
    start_server() {
      local attempt

      for attempt in 1 2 3 4 5; do
        port=$(shuf -i 10000-65535 -n 1)
        if port_is_listening "$port"; then
          continue
        fi

        simple-http-server -i --port "$port" . >"$server_log" 2>&1 &
        server_pid=$!

        if wait_for_port "$port"; then
          return 0
        fi

        echo "simple-http-server did not start on port $port (attempt $attempt)." >&2
        stop_children
      done

      echo "Could not start simple-http-server in $root after 5 attempts." >&2
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
    }

    # cloudflared reports the URL before the tunnel is connected, so the public URL
    # is reported as printed rather than probed for reachability.
    await_children() {
      if [ -z "$tunnel_pid" ]; then
        wait "$server_pid" || true
        echo "simple-http-server stopped." >&2
        exit 1
      fi

      wait -n "$server_pid" "$tunnel_pid" || true

      if kill -0 "$server_pid" 2>/dev/null; then
        echo "cloudflared stopped; stopping the HTTP server." >&2
        tail -n 10 "$tunnel_log" >&2 || true
      else
        echo "simple-http-server stopped; stopping the tunnel." >&2
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

        sleep 0.25
      done

      return 1
    }

    main "$@"
  '';
}
