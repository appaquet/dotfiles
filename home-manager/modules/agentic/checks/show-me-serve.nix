{ pkgs }:

# Smoke test for the packaged command: it serves the requested folder, opens a
# public tunnel only when asked, and leaves no child process behind. cloudflared is
# replaced by a local fake so the check stays offline.
let
  fakeCloudflared = pkgs.writeShellApplication {
    name = "cloudflared";

    runtimeInputs = [ pkgs.coreutils ];

    text = ''
      printf '%s\n' \
        '2026-09-23T16:06:02Z INF |  Your quick Tunnel has been created! Visit it at (it may take some time to be reachable):  |' \
        '2026-09-23T16:06:02Z INF |  https://check-fixture-quick-tunnel.trycloudflare.com                        |' >&2

      while :; do
        sleep 1
      done
    '';
  };

  testShowMeServe = pkgs.callPackage ../tools/show-me-serve.nix {
    pkgs = pkgs // {
      cloudflared = fakeCloudflared;
    };
  };
in
pkgs.runCommand "agentic-show-me-serve-check"
  {
    nativeBuildInputs = [
      testShowMeServe
      pkgs.coreutils
      pkgs.curl
      pkgs.gnugrep
      pkgs.procps
    ];
  }
  ''
    set -eu

    served="$TMPDIR/served"
    mkdir -p "$served"
    printf 'show-me-serve-check-payload\n' >"$served/hello.txt"

    fail() {
      echo "$1" >&2
      cat "$log" >&2
      exit 1
    }

    # Starts the command in the given mode, waits for the internal URL, fetches the
    # served file, stops it, and asserts nothing survives.
    exercise() {
      mode="$1"
      log="$TMPDIR/$mode.log"

      if [ "$mode" = "public" ]; then
        agentic-show-me-serve --public "$served" >"$log" 2>&1 &
      else
        agentic-show-me-serve "$served" >"$log" 2>&1 &
      fi

      tool_pid=$!

      internal_url=""
      for _ in $(seq 1 60); do
        internal_url=$(grep -oE 'http://[^ ]+/' "$log" 2>/dev/null | head -n 1 || true)

        if [ -n "$internal_url" ]; then
          break
        fi

        sleep 0.5
      done

      [ -n "$internal_url" ] || fail "No internal URL sentence was printed."

      port=$(printf '%s' "$internal_url" | sed -n 's|^.*:\([0-9]\+\)/$|\1|p')
      [ -n "$port" ] || fail "Could not read a port from '$internal_url'."

      # A wrong working directory in the command yields a 404 here.
      [ "$(curl -fsS "http://127.0.0.1:$port/hello.txt")" = "show-me-serve-check-payload" ] || fail "The served file content did not match."

      if [ "$mode" = "private" ] && pgrep -f cloudflared >/dev/null; then
        fail "The command started cloudflared without --public."
      fi

      kill -TERM "$tool_pid"
      wait "$tool_pid" 2>/dev/null || true

      if (exec 3<>"/dev/tcp/127.0.0.1/$port") 2>/dev/null; then
        echo "Port $port is still listening after termination." >&2
        exit 1
      fi

      if pgrep -f 'simple-http-server -i --port' >/dev/null || pgrep -f cloudflared >/dev/null; then
        echo "A child process survived termination." >&2
        exit 1
      fi
    }

    exercise private

    if grep -q 'trycloudflare' "$log"; then
      fail "The command opened a public tunnel without --public."
    fi

    exercise public

    public_url=$(grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' "$log" | head -n 1 || true)
    [ "$public_url" = "https://check-fixture-quick-tunnel.trycloudflare.com" ] || fail "Unexpected public URL '$public_url'."

    touch "$out"
  ''
