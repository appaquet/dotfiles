{ pkgs }:

# Smoke test for the packaged command: it serves the requested folder with the
# right mode for each path, opens a public tunnel only when asked, and leaves no
# child process behind. cloudflared is replaced by a local fake so the check
# stays offline; the per-route protocol cases live in the Bun test suite.
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

  # A tunnel that dies before reporting a URL must not take the server down with it.
  fakeDeadCloudflared = pkgs.writeShellApplication {
    name = "cloudflared";

    text = ''
      echo 'cloudflared: failed to connect to the edge' >&2
      exit 1
    '';
  };

  testShowMeServe = pkgs.callPackage ../tools/show-me-serve.nix {
    pkgs = pkgs // {
      cloudflared = fakeCloudflared;
    };
  };

  testShowMeServeDeadTunnel = pkgs.callPackage ../tools/show-me-serve.nix {
    pkgs = pkgs // {
      cloudflared = fakeDeadCloudflared;
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
    mkdir -p "$served/docs"
    printf 'show-me-serve-check-payload\n' >"$served/hello.txt"
    printf '# Notes\n\nCheck document.\n' >"$served/docs/notes.md"
    printf '<h1>artifact</h1>\n' >"$served/artifact.html"

    fail() {
      echo "$1" >&2
      cat "$log" >&2
      exit 1
    }

    # Starts the command in the given mode, waits for the internal URL, checks the
    # generated index, an ordinary file, and the Markdown modes, stops it, and
    # asserts nothing survives.
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

      # The tunnel URL arrives after the internal one, so wait for it here rather
      # than after the command has already been stopped.
      if [ "$mode" = "public" ]; then
        public_url=""
        for _ in $(seq 1 60); do
          public_url=$(grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' "$log" 2>/dev/null | head -n 1 || true)

          if [ -n "$public_url" ]; then
            break
          fi

          sleep 0.5
        done

        [ "$public_url" = "https://check-fixture-quick-tunnel.trycloudflare.com" ] || fail "Unexpected public URL '$public_url'."
      fi

      port=$(printf '%s' "$internal_url" | sed -n 's|^.*:\([0-9]\+\)/$|\1|p')
      [ -n "$port" ] || fail "Could not read a port from '$internal_url'."

      base="http://127.0.0.1:$port"

      # A wrong working directory in the command yields a 404 here.
      [ "$(curl -fsS "$base/hello.txt")" = "show-me-serve-check-payload" ] || fail "The served file content did not match."

      # The root URL is a generated index that links the served entries.
      index=$(curl -fsS "$base/")
      printf '%s' "$index" | grep -q 'href="/hello.txt"' || fail "The root index does not link hello.txt."
      printf '%s' "$index" | grep -q 'href="/docs/"' || fail "The root index does not link the docs directory."

      # An ordinary HTML file is served unchanged.
      curl -fsS "$base/artifact.html" | grep -q '<h1>artifact</h1>' || fail "The HTML artifact was not served unchanged."

      # Markdown returns the packaged reader shell, and raw mode returns the source.
      curl -fsS "$base/docs/notes.md" | grep -q 'class="smd-doc"' || fail "Markdown did not return the packaged reader shell."
      [ "$(curl -fsS "$base/docs/notes.md?raw=1")" = "$(printf '# Notes\n\nCheck document.')" ] || fail "Raw Markdown did not match the source."

      # The docs tree reports root-relative Markdown paths only.
      tree=$(curl -fsS "$base/_show-me/tree")
      printf '%s' "$tree" | grep -q '"docs/notes.md"' || fail "The docs tree is missing docs/notes.md."
      printf '%s' "$tree" | grep -q 'hello.txt' && fail "The docs tree listed a non-Markdown file."

      # The packaged feedback asset is reachable under the reserved namespace.
      curl -fsS "$base/_show-me/feedback.js" | grep -q 'mountFeedback' || fail "The shared feedback asset was not served."

      if [ "$mode" = "private" ] && pgrep -f cloudflared >/dev/null; then
        fail "The command started cloudflared without --public."
      fi

      kill -TERM "$tool_pid"
      wait "$tool_pid" 2>/dev/null || true

      if (exec 3<>"/dev/tcp/127.0.0.1/$port") 2>/dev/null; then
        echo "Port $port is still listening after termination." >&2
        exit 1
      fi

      if pgrep -f 'show-me-serve.ts' >/dev/null || pgrep -f cloudflared >/dev/null; then
        echo "A child process survived termination." >&2
        exit 1
      fi
    }

    exercise private

    if grep -q 'trycloudflare' "$log"; then
      fail "The command opened a public tunnel without --public."
    fi

    exercise public

    # A tunnel that never reports a URL leaves the HTTP server serving internally.
    log="$TMPDIR/dead-tunnel.log"
    ${testShowMeServeDeadTunnel}/bin/agentic-show-me-serve --public "$served" >"$log" 2>&1 &
    tool_pid=$!

    internal_url=""
    for _ in $(seq 1 60); do
      internal_url=$(grep -oE 'http://[^ ]+/' "$log" 2>/dev/null | head -n 1 || true)

      if [ -n "$internal_url" ]; then
        break
      fi

      sleep 0.5
    done

    [ -n "$internal_url" ] || fail "No internal URL sentence was printed without a tunnel."
    grep -q 'serving internally only' "$log" || fail "The command did not report internal-only serving."

    port=$(printf '%s' "$internal_url" | sed -n 's|^.*:\([0-9]\+\)/$|\1|p')
    [ -n "$port" ] || fail "Could not read a port from '$internal_url'."
    [ "$(curl -fsS "http://127.0.0.1:$port/hello.txt")" = "show-me-serve-check-payload" ] || fail "The server stopped serving after the tunnel failed."

    kill -TERM "$tool_pid"
    wait "$tool_pid" 2>/dev/null || true

    if (exec 3<>"/dev/tcp/127.0.0.1/$port") 2>/dev/null; then
      echo "Port $port is still listening after termination." >&2
      exit 1
    fi

    touch "$out"
  ''
