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

  # Records hc invocations to verify label set/clear lifecycle without a live core.
  fakeHc = pkgs.writeShellApplication {
    name = "hc";

    runtimeInputs = [ pkgs.coreutils ];

    text = ''
      printf '%s\n' "$*" >> "$FAKE_HC_LOG"

      if [ -n "''${FAKE_HC_FAIL:-}" ]; then
        exit 1
      fi
    '';
  };

  testShowMeServe = pkgs.callPackage ../tools/show-me/show-me-serve.nix {
    pkgs = pkgs // {
      cloudflared = fakeCloudflared;
    };
  };

  testShowMeServeDeadTunnel = pkgs.callPackage ../tools/show-me/show-me-serve.nix {
    pkgs = pkgs // {
      cloudflared = fakeDeadCloudflared;
    };
  };
in
pkgs.runCommand "show-me-serve-check"
  {
    nativeBuildInputs = [
      testShowMeServe
      pkgs.coreutils
      pkgs.curl
      pkgs.gnugrep
      pkgs.unixtools.ps
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

      if [ -n "${"log:-"}" ] && [ -f "${"log:-"}" ]; then
        cat "$log" >&2
      fi

      exit 1
    }

    # Snapshot first so the matcher cannot find its own command line.
    process_is_running() {
      ps -A -o args= >"$TMPDIR/processes" || fail "Could not inspect processes."
      grep -q -- "$1" "$TMPDIR/processes"
    }

    # Greps a captured body for a marker. Bodies are written to a file first:
    # piping into grep lets the reader exit at the first match, which truncates
    # the writer and can fail the build.
    expect_contains() {
      content="$1"
      marker="$2"
      message="$3"

      printf '%s' "$content" >"$TMPDIR/body"
      grep -q -- "$marker" "$TMPDIR/body" || fail "$message"
    }

    reject_contains() {
      content="$1"
      marker="$2"
      message="$3"

      printf '%s' "$content" >"$TMPDIR/body"

      if grep -q -- "$marker" "$TMPDIR/body"; then
        fail "$message"
      fi
    }

    # Downloads a served path and checks its body contains a marker.
    expect_served() {
      url="$1"
      marker="$2"
      message="$3"

      curl -fsS --output "$TMPDIR/body" "$url" || fail "$message"
      grep -q -- "$marker" "$TMPDIR/body" || fail "$message"
    }

    # Help and argument handling never start a server.
    "${testShowMeServe}/bin/show-me-serve" --help >"$TMPDIR/help.log" 2>&1
    grep -q 'Usage: show-me-serve \[--public\] \[directory\]' "$TMPDIR/help.log" || fail "The help output does not show the usage line."
    grep -q 'defaults to the current one' "$TMPDIR/help.log" || fail "The help output does not document the default directory."
    grep -q -- '--public' "$TMPDIR/help.log" || fail "The help output does not document --public."
    grep -q 'document reader' "$TMPDIR/help.log" || fail "The help output does not document the automatic modes."
    grep -q 'Serving' "$TMPDIR/help.log" && fail "The help path started serving."
    "${testShowMeServe}/bin/show-me-serve" -h | grep -q 'Usage: show-me-serve' || fail "The short help flag did not print the usage line."

    if process_is_running 'show-me-serve.ts'; then
      fail "The help path left a server process behind."
    fi

    if "${testShowMeServe}/bin/show-me-serve" "$served" extra >"$TMPDIR/extra.log" 2>&1; then
      fail "Extra arguments were accepted."
    fi

    grep -q 'Usage: show-me-serve' "$TMPDIR/extra.log" || fail "Extra arguments did not print the usage hint."

    if "${testShowMeServe}/bin/show-me-serve" --nope "$served" >"$TMPDIR/unknown.log" 2>&1; then
      fail "An unknown option was accepted."
    fi

    grep -q "Unknown option '--nope'" "$TMPDIR/unknown.log" || fail "An unknown option did not report the expected message."

    if "${testShowMeServe}/bin/show-me-serve" "$TMPDIR/missing" >"$TMPDIR/missing.log" 2>&1; then
      fail "A missing directory was accepted."
    fi

    grep -q 'not an existing directory' "$TMPDIR/missing.log" || fail "A missing directory did not report the expected message."

    # Starts the command in the given mode, waits for the internal URL, checks the
    # generated index, an ordinary file, and the Markdown modes, stops it, and
    # asserts nothing survives.
    exercise() {
      mode="$1"
      log="$TMPDIR/$mode.log"

      # The cwd case proves the directory argument is optional: the command
      # serves the working directory when none is given.
      if [ "$mode" = "cwd" ]; then
        ( cd "$served" && exec show-me-serve >"$log" 2>&1 ) &
      elif [ "$mode" = "public" ]; then
        show-me-serve --public "$served" >"$log" 2>&1 &
      else
        show-me-serve "$served" >"$log" 2>&1 &
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
      expect_contains "$index" 'href="/hello.txt"' "The root index does not link hello.txt."
      expect_contains "$index" 'href="/docs/"' "The root index does not link the docs directory."

      # An ordinary HTML file is served unchanged.
      expect_served "$base/artifact.html" '<h1>artifact</h1>' "The HTML artifact was not served unchanged."

      # Markdown returns the packaged reader shell, and raw mode returns the source.
      expect_served "$base/docs/notes.md" 'class="smd-doc"' "Markdown did not return the packaged reader shell."
      [ "$(curl -fsS "$base/docs/notes.md?raw=1")" = "$(printf '# Notes\n\nCheck document.')" ] || fail "Raw Markdown did not match the source."

      # The docs tree reports root-relative Markdown paths only.
      tree=$(curl -fsS "$base/_show-me/tree")
      expect_contains "$tree" '"docs/notes.md"' "The docs tree is missing docs/notes.md."
      reject_contains "$tree" 'hello.txt' "The docs tree listed a non-Markdown file."

      # The packaged feedback asset is reachable under the reserved namespace.
      expect_served "$base/_show-me/feedback.js" 'mountFeedback' "The shared feedback asset was not served."
      expect_served "$base/_show-me/feedback-auto.js" 'data-target-id' "The one-line feedback entry was not served."

      # The diagram runtime is packaged the same way, so both serving paths share it.
      expect_served "$base/_show-me/diagrams.js" 'mountDiagrams' "The diagram runtime was not served."
      expect_served "$base/_show-me/diagrams-auto.js" 'mountDiagrams' "The one-line diagram entry was not served."
      expect_served "$base/_show-me/diagrams.css" 'smdg' "The diagram stylesheet was not served."

      if [ "$mode" != "public" ] && process_is_running cloudflared; then
        fail "The command started cloudflared without --public."
      fi

      process_is_running 'show-me-serve.ts' || fail "The running server was not visible to the process check."

      kill -TERM "$tool_pid"
      wait "$tool_pid" 2>/dev/null || true

      if (exec 3<>"/dev/tcp/127.0.0.1/$port") 2>/dev/null; then
        echo "Port $port is still listening after termination." >&2
        exit 1
      fi

      if process_is_running 'show-me-serve.ts' || process_is_running cloudflared; then
        echo "A child process survived termination." >&2
        exit 1
      fi
    }

    exercise private

    if grep -q 'trycloudflare' "$log"; then
      fail "The command opened a public tunnel without --public."
    fi

    exercise public
    exercise cwd

    # A tunnel that never reports a URL leaves the HTTP server serving internally.
    log="$TMPDIR/dead-tunnel.log"
    ${testShowMeServeDeadTunnel}/bin/show-me-serve --public "$served" >"$log" 2>&1 &
    tool_pid=$!

    internal_url=""
    for _ in $(seq 1 60); do
      internal_url=$(grep -oE 'http://[^ ]+/' "$log" 2>/dev/null | head -n 1 || true)

      if [ -n "$internal_url" ] && grep -q 'serving internally only' "$log"; then
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

    # Inside an hc terminal, show-me-serve sets the label on start and clears it on SIGTERM.
    hc_log="$TMPDIR/hc.log"
    : >"$hc_log"
    log="$TMPDIR/hc-label.log"
    HC_TERMINAL_ID=t99 FAKE_HC_LOG="$hc_log" PATH="${fakeHc}/bin:$PATH" \
      show-me-serve "$served" >"$log" 2>&1 &
    tool_pid=$!

    internal_url=""
    for _ in $(seq 1 60); do
      internal_url=$(grep -oE 'http://[^ ]+/' "$log" 2>/dev/null | head -n 1 || true)

      if [ -n "$internal_url" ]; then
        break
      fi

      sleep 0.5
    done

    [ -n "$internal_url" ] || fail "No internal URL sentence was printed in the hc-label test."
    port=$(printf '%s' "$internal_url" | sed -n 's|^.*:\([0-9]\+\)/$|\1|p')
    [ -n "$port" ] || fail "Could not read a port from '$internal_url' in the hc-label test."

    grep -Fxq "label t99 show-me.$port=$internal_url" "$hc_log" || fail "Expected hc label set call, got: $(cat "$hc_log")"

    kill -TERM "$tool_pid"
    wait "$tool_pid" 2>/dev/null || true

    grep -Fxq "label t99 show-me.$port=" "$hc_log" || fail "Expected hc label clear call, got: $(cat "$hc_log")"

    # A failing hc binary must never stop show-me-serve from serving.
    hc_fail_log="$TMPDIR/hc-fail.log"
    : >"$hc_fail_log"
    log="$TMPDIR/hc-fail-serve.log"
    HC_TERMINAL_ID=t99 FAKE_HC_LOG="$hc_fail_log" FAKE_HC_FAIL=1 PATH="${fakeHc}/bin:$PATH" \
      show-me-serve "$served" >"$log" 2>&1 &
    tool_pid=$!

    internal_url=""
    for _ in $(seq 1 60); do
      internal_url=$(grep -oE 'http://[^ ]+/' "$log" 2>/dev/null | head -n 1 || true)

      if [ -n "$internal_url" ]; then
        break
      fi

      sleep 0.5
    done

    [ -n "$internal_url" ] || fail "No internal URL sentence was printed when hc fails."
    port=$(printf '%s' "$internal_url" | sed -n 's|^.*:\([0-9]\+\)/$|\1|p')
    [ "$(curl -fsS "http://127.0.0.1:$port/hello.txt")" = "show-me-serve-check-payload" ] || fail "Server did not serve when hc failed."

    kill -TERM "$tool_pid"
    wait "$tool_pid" 2>/dev/null || true

    if grep -Fxq "label t99 show-me.$port=" "$hc_fail_log"; then
      fail "Should not attempt to clear a label that failed to set."
    fi
    touch "$out"
  ''
