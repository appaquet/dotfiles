{
  home-manager,
  lib,
  nono,
  pkgs,
  upstreamPi,
}:

let
  # Loading a real npm-shaped extension exercises Pi's package discovery and
  # protects the Node runtime required by extensions that import node:sqlite.
  extensionFixture = pkgs.runCommand "pi-runtime-extension-fixture" { } ''
    mkdir -p "$out/extensions"
    cat >"$out/package.json" <<'JSON'
    {"name":"pi-runtime-extension-fixture","pi":{"extensions":["./extensions"]}}
    JSON
    cat >"$out/extensions/probe.ts" <<'TS'
    import { DatabaseSync } from "node:sqlite";

    export default function (pi: any) {
      const database = new DatabaseSync(":memory:");
      database.exec("CREATE TABLE smoke (value TEXT)");
      database.close();
      pi.registerCommand("smoke-probe", {
        description: "deterministic runtime smoke probe",
        handler: async () => {},
      });
    }
    TS
  '';

  backgroundBashPin = "npm:@haphazarddev/pi-background-bash@0.1.0";
  configuredPluginModule = import ../plugins/default.nix {
    config.sops.secrets.pi_exa_api_key.path = "/run/secrets/pi_exa_api_key";
    inherit lib;
  };
  configuredPluginPackages = configuredPluginModule.dotfiles.pi.settings.packages;
  backgroundBashConfig =
    builtins.fromJSON
      configuredPluginModule.home.file.".pi/agent/extensions/pi-background-bash/config.json".text;

  backgroundBashArchive = pkgs.fetchurl {
    url = "https://registry.npmjs.org/@haphazarddev/pi-background-bash/-/pi-background-bash-0.1.0.tgz";
    hash = "sha512-dN/z3YNsimwAA9TjQcLceZJlFvG6HniIXOikUCa99gMuHf3TVl6fnQqf2a0LjEBFsFPL+vToVYqaVVkRjKJsQg==";
  };
  sinclairTypeboxArchive = pkgs.fetchurl {
    url = "https://registry.npmjs.org/@sinclair/typebox/-/typebox-0.34.52.tgz";
    hash = "sha512-XiMQh7qqVlxZzcVD+kkGMNGMzcTrDMLWI7S4x7z1MkCkbDPrekpZXEUK0eZqZFMuHQg2a2DZOcDIh9o5v3Gonw==";
  };

  # The smoke test executes the package selected by the production module, not
  # a separately chosen test package that could drift from production.
  productionHome = home-manager.lib.homeManagerConfiguration {
    inherit pkgs;
    extraSpecialArgs.inputs'.llm-agents.packages.pi = upstreamPi;
    modules = [
      ../module.nix
      {
        home = {
          username = "pi-runtime";
          homeDirectory = "/home/pi-runtime";
          stateVersion = "24.11";
        };
        dotfiles.pi.enable = true;
      }
    ];
  };
  selectedPi = productionHome.config.dotfiles.pi.package;

  backgroundBashFixture = pkgs.runCommand "pi-background-bash-fixture" { } ''
    mkdir -p "$out" "$out/node_modules/@sinclair" "$out/node_modules/@earendil-works"
    tar -xzf ${backgroundBashArchive} --strip-components=1 -C "$out"
    mkdir -p "$out/node_modules/@sinclair/typebox"
    tar -xzf ${sinclairTypeboxArchive} --strip-components=1 -C "$out/node_modules/@sinclair/typebox"
    ln -s ${selectedPi}/lib/node_modules/@earendil-works/pi-coding-agent \
      "$out/node_modules/@earendil-works/pi-coding-agent"
    ln -s ${selectedPi}/lib/node_modules/@earendil-works/pi-coding-agent/node_modules/@earendil-works/pi-tui \
      "$out/node_modules/@earendil-works/pi-tui"
  '';

  backgroundBashSmoke =
    pkgs.runCommand "pi-background-bash-smoke"
      {
        nativeBuildInputs = [
          pkgs.bun
          pkgs.jq
          pkgs.nodejs
        ];
      }
      ''
        export HOME="$TMPDIR/home"
        export PI_CODING_AGENT_DIR="$HOME/.pi/agent"
        mkdir -p "$PI_CODING_AGENT_DIR/extensions"
        printf '%s\n' '{"packages":["${backgroundBashFixture}"]}' > "$PI_CODING_AGENT_DIR/settings.json"

        cat > "$PI_CODING_AGENT_DIR/extensions/background-smoke-probe.ts" <<'TS'
        import { writeFileSync } from "node:fs";

        export default function (pi: any) {
          pi.on("session_start", async () => {
            const tools = pi
              .getAllTools()
              .map((tool: { name: string }) => tool.name)
              .filter((name: string) => name.startsWith("background_bash_"))
              .sort();
            writeFileSync(process.env.BACKGROUND_BASH_TOOLS_FILE!, JSON.stringify(tools));
          });
        }
        TS

        export BACKGROUND_BASH_TOOLS_FILE="$HOME/background-tools.json"
        test "$(${selectedPi}/bin/pi --version)" = "0.85.1"
        printf '%s\n' '{"id":"probe","type":"get_commands"}' \
          | timeout 30 ${selectedPi}/bin/pi --mode rpc --no-session --no-approve \
          > "$HOME/response.jsonl"
        jq -e '
          . == [
            "background_bash_list",
            "background_bash_logs",
            "background_bash_start",
            "background_bash_status",
            "background_bash_stop"
          ]
        ' "$BACKGROUND_BASH_TOOLS_FILE"
        jq -s -e '
          any(.[].data.commands[]?; .name == "ps")
        ' "$HOME/response.jsonl"

        printf '%s\n' '{"defaultTimeoutSeconds":300,"maxTimeoutSeconds":1200}' \
          > "$PI_CODING_AGENT_DIR/bash-timeout.json"
        cat > policy-smoke.ts <<'TS'
        import assert from "node:assert/strict";
        import backgroundBashExtension from "${backgroundBashFixture}/dist/index.js";
        import bashTimeoutExtension from "${../plugins/bash-timeout.ts}";

        const handlers = new Map<string, Array<(event: any) => any>>();
        const pi = {
          registerTool() {},
          registerCommand() {},
          registerShortcut() {},
          on(event: string, handler: (event: any) => any) {
            const current = handlers.get(event) ?? [];
            current.push(handler);
            handlers.set(event, current);
          },
        };

        backgroundBashExtension(pi as any);
        bashTimeoutExtension(pi as any);

        const toolCallHandlers = handlers.get("tool_call") ?? [];
        assert.equal(toolCallHandlers.length, 1, "only the local timeout policy may mutate native Bash");

        const omitted = { toolName: "bash", input: { command: "true" } };
        for (const handler of toolCallHandlers) await handler(omitted);
        assert.equal(omitted.input.timeout, 300);

        const aboveCeiling = { toolName: "bash", input: { command: "true", timeout: 1201 } };
        let decision;
        for (const handler of toolCallHandlers) decision = await handler(aboveCeiling);
        assert.equal(decision.block, true);
        assert.match(decision.reason, /1200/);
        TS
        bun policy-smoke.ts

        cat > smoke.mjs <<'JS'
        import assert from "node:assert/strict";
        import { readFile } from "node:fs/promises";
        import { createBackgroundBashExtension } from "${backgroundBashFixture}/dist/index.js";

        const tools = new Map();
        const handlers = new Map();
        const messages = [];
        let completionResolve;
        let completion = new Promise((resolve) => {
          completionResolve = resolve;
        });

        const pi = {
          registerTool(tool) {
            tools.set(tool.name, tool);
          },
          registerCommand() {},
          registerShortcut() {},
          on(event, handler) {
            const current = handlers.get(event) ?? [];
            current.push(handler);
            handlers.set(event, current);
          },
          sendMessage(message, options) {
            messages.push({ message, options });
            completionResolve({ message, options });
          },
        };

        createBackgroundBashExtension({
          loadConfig: () => ({
            config: {
              shortcut: "ctrl+alt+k",
              widgetIcon: "",
              completionNotifications: false,
              showLatestCompleted: false,
            },
            diagnostics: [],
          }),
        })(pi);

        const expectedTools = [
          "background_bash_list",
          "background_bash_logs",
          "background_bash_start",
          "background_bash_status",
          "background_bash_stop",
        ];
        assert.deepEqual([...tools.keys()].sort(), expectedTools);
        assert.equal(handlers.has("tool_call"), false, "extension must not mutate native Bash calls");

        const ui = {
          notify() {},
          setWidget() {},
        };
        const ctx = { cwd: process.cwd(), hasUI: false, mode: "rpc", ui };
        for (const handler of handlers.get("session_start") ?? []) {
          await handler({}, ctx);
        }

        const start = tools.get("background_bash_start");
        const list = tools.get("background_bash_list");
        const status = tools.get("background_bash_status");
        const logs = tools.get("background_bash_logs");
        const stop = tools.get("background_bash_stop");

        const successful = await start.execute(
          "success",
          { command: "printf 'stdout-ok\\n'; printf 'stderr-ok\\n' >&2", notifyAgent: true },
          new AbortController().signal,
          undefined,
          ctx,
        );
        const successJob = successful.details;
        const notice = await Promise.race([
          completion,
          new Promise((_, reject) => setTimeout(() => reject(new Error("completion wake timed out")), 5000)),
        ]);
        assert.equal(notice.options.triggerTurn, true);
        assert.equal(notice.options.deliverAs, "followUp");
        assert.equal(messages.length, 1);

        const listed = await list.execute("list");
        assert.equal(listed.details.some((job) => job.id === successJob.id), true);
        const successStatus = await status.execute("status", { id: successJob.id });
        assert.equal(successStatus.details.status, "exited");
        assert.equal(successStatus.details.exitCode, 0);
        const successLogs = await logs.execute("logs", { id: successJob.id, limit: 20 });
        assert.match(successLogs.content[0].text, /stdout-ok/);
        assert.match(successLogs.content[0].text, /stderr-ok/);
        assert.match(await readFile(successJob.logPath, "utf8"), /stdout-ok/);

        const failed = await start.execute(
          "failure",
          { command: "exit 23", notifyAgent: false },
          new AbortController().signal,
          undefined,
          ctx,
        );
        await waitForTerminal(status, failed.details.id);
        const failedStatus = await status.execute("failed-status", { id: failed.details.id });
        assert.equal(failedStatus.details.status, "failed");
        assert.equal(failedStatus.details.exitCode, 23);

        const timed = await start.execute(
          "timeout",
          { command: "sleep 300", timeoutSeconds: 0.05, notifyAgent: false },
          new AbortController().signal,
          undefined,
          ctx,
        );
        await waitForTerminal(status, timed.details.id);
        const timedStatus = await status.execute("timeout-status", { id: timed.details.id });
        assert.equal(timedStatus.details.status, "timed_out");
        assertProcessGroupGone(timed.details.pid);

        const runningStartedAt = Date.now();
        const running = await start.execute(
          "stop",
          { command: "sleep 300 & wait", notifyAgent: false },
          new AbortController().signal,
          undefined,
          ctx,
        );
        assert.ok(Date.now() - runningStartedAt < 2000, "background start must return promptly");
        const stopped = await stop.execute("stop-job", { id: running.details.id });
        assert.equal(stopped.details.job.status, "stopped");
        assertProcessGroupGone(running.details.pid);

        completion = new Promise((resolve) => {
          completionResolve = resolve;
        });
        const shutdownJob = await start.execute(
          "shutdown",
          { command: "sleep 300 & wait", notifyAgent: true },
          new AbortController().signal,
          undefined,
          ctx,
        );
        for (const handler of handlers.get("session_shutdown") ?? []) {
          await handler({}, ctx);
        }
        await new Promise((resolve) => setTimeout(resolve, 100));
        assertProcessGroupGone(shutdownJob.details.pid);
        assert.equal(messages.length, 1, "shutdown must suppress delayed completion wakeups");

        async function waitForTerminal(statusTool, id) {
          const deadline = Date.now() + 5000;
          while (Date.now() < deadline) {
            const result = await statusTool.execute("wait", { id });
            if (result.details.status !== "running") return;
            await new Promise((resolve) => setTimeout(resolve, 10));
          }
          throw new Error("job " + id + " did not settle");
        }

        function assertProcessGroupGone(pid) {
          assert.notEqual(pid, null);
          assert.throws(() => process.kill(-pid, 0), { code: "ESRCH" });
        }
        JS

        node smoke.mjs
        touch "$out"
      '';

  runtimeSmoke = pkgs.runCommand "pi-node-runtime-smoke" { nativeBuildInputs = [ pkgs.jq ]; } ''
    export HOME="$TMPDIR/home"
    export PI_CODING_AGENT_DIR="$HOME/.pi/agent"
    export PI_OFFLINE=1
    mkdir -p "$PI_CODING_AGENT_DIR"
    printf '%s\n' '{"packages":["${extensionFixture}"]}' >"$PI_CODING_AGENT_DIR/settings.json"

    printf '%s\n' '{"id":"probe","type":"get_commands"}' \
      | timeout 30 ${selectedPi}/bin/pi --mode rpc --no-session --no-approve \
      >"$HOME/response.jsonl"
    jq -s -e '
      any(.[].data.commands[]?; .name == "smoke-probe")
    ' "$HOME/response.jsonl"
    touch "$out"
  '';

  # Nono cannot run inside the Nix build sandbox. This generated host smoke
  # validates the real profile, helper commands, wrapper, and secret boundary.
  fakeSecret = pkgs.writeText "pi-nono-smoke-secret" "expected-secret";
  fakePi = pkgs.writeShellScriptBin "pi" ''
    printf 'secret=%s\nnpm-version=%s\narg=%s\n' \
      "''${SMOKE_SECRET-}" "$(npm --version)" "$1" \
      >"$HOME/.pi/agent/nono-invocation"
  '';
  smokePkgs = pkgs.extend (_: _: { inherit nono; });
  smokeHome = home-manager.lib.homeManagerConfiguration {
    pkgs = smokePkgs;
    extraSpecialArgs.inputs'.llm-agents.packages.pi = upstreamPi;
    extraSpecialArgs.inputs'.llm-agents.packages.nono = nono;
    modules = [
      ../../../nono/default.nix
      ../module.nix
      {
        home = {
          username = "pi-smoke";
          homeDirectory = "/home/pi-smoke";
          stateVersion = "24.11";
        };
        dotfiles.pi = {
          enable = true;
          package = fakePi;
          settings.smoke = "generated";
          environment.SMOKE_SECRET.file = toString fakeSecret;
        };
        dotfiles.nono.profiles.pi = {
          meta.version = "1.0.0";
          extends = "coding-agent";
          filesystem = {
            allow = [
              "$HOME/.pi"
              "$HOME/.local/share/pi"
            ];
            read_file = [ (toString fakeSecret) ];
          };
          security.signal_mode = "allow_all";
          network.block = true;
        };
      }
    ];
  };
  packages = smokeHome.config.home.packages;
  nonoPi = lib.findFirst (package: lib.getName package == "nono-pi") null packages;
  maybePackages = builtins.filter (package: lib.hasPrefix "maybe" (lib.getName package)) packages;
  profileSource = name: smokeHome.config.home.file.".config/nono/profiles/${name}.json".source;

  nonoSmoke = pkgs.writeShellApplication {
    name = "pi-nono-smoke";
    runtimeInputs = [
      nono
      pkgs.coreutils
      pkgs.jq
    ]
    ++ maybePackages;
    text = ''
      test "$(uname -s)" = Linux
      # A private worktree prevents repository-local nono hooks from affecting
      # the result and keeps every runtime write under the disposable HOME.
      home="$(mktemp -d /var/tmp/pi-nono-smoke.XXXXXX)"
      trap 'rm -rf "$home"' EXIT HUP INT TERM
      mkdir -p "$home/.config/nono/profiles" "$home/.pi" "$home/.local/share/pi" "$home/work"
      cp ${profileSource "machine"} "$home/.config/nono/profiles/machine.json"
      cp ${profileSource "coding-agent"} "$home/.config/nono/profiles/coding-agent.json"
      cp ${profileSource "pi"} "$home/.config/nono/profiles/pi.json"
      cd "$home/work"

      HOME="$home" ${nonoPi}/bin/nono-pi smoke-argument
      jq -e '.smoke == "generated"' "$home/.pi/agent/settings.json"
      printf '%s\n' \
        'secret=expected-secret' \
        "npm-version=$(${pkgs.nodejs}/bin/npm --version)" \
        'arg=smoke-argument' \
        >"$home/expected"
      diff -u "$home/expected" "$home/.pi/agent/nono-invocation"
    '';
  };

  # --- auth.json merge smoke ---
  # The wrapper merges the sops-managed fragment into the live auth.json at
  # launch (managed providers win, pi-managed entries preserved) and must not
  # leak managed keys into the process environment.
  goodAuthFragment = pkgs.writeText "pi-auth-good-fragment" ''
    {"opencode-go":{"type":"api_key","key":"managed-opencode"},"cerebras":{"type":"api_key","key":"managed-cerebras"}}
  '';
  badAuthFragment = pkgs.writeText "pi-auth-bad-fragment" "not-a-json-object";

  # Stand-in pi that records the environment the wrapper passes on.
  authProbePi = pkgs.writeShellScriptBin "pi" ''
    printf 'OPENCODE_API_KEY=%s\n' "''${OPENCODE_API_KEY-}" >"$HOME/.pi/agent/auth-probe"
  '';

  mkAuthHome =
    fragment:
    home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      extraSpecialArgs.inputs'.llm-agents.packages.pi = upstreamPi;
      modules = [
        ../module.nix
        {
          home = {
            username = "pi-auth";
            homeDirectory = "/home/pi-auth";
            stateVersion = "24.11";
          };
          dotfiles.pi = {
            enable = true;
            package = authProbePi;
            authFile = toString fragment;
          };
        }
      ];
    };
  authWrapper =
    fragment: lib.findFirst (p: lib.getName p == "pi") null (mkAuthHome fragment).config.home.packages;

  authMergeSmoke = pkgs.runCommand "pi-auth-merge-smoke" { nativeBuildInputs = [ pkgs.jq ]; } ''
    set -e
    export HOME="$TMPDIR/home"
    mkdir -p "$HOME/.pi/agent"

    # Seed a pi-managed OAuth entry plus a stale managed key the fragment must
    # override.
    printf '%s\n' \
      '{"openai-codex":{"type":"oauth","access":"codex-at","refresh":"codex-rt","expires":1},"opencode-go":{"type":"api_key","key":"stale"}}' \
      >"$HOME/.pi/agent/auth.json"

    ${authWrapper goodAuthFragment}/bin/pi

    jq -e 'type == "object"' "$HOME/.pi/agent/auth.json"
    jq -e '.["opencode-go"].key == "managed-opencode"' "$HOME/.pi/agent/auth.json"
    jq -e '.cerebras.key == "managed-cerebras"' "$HOME/.pi/agent/auth.json"
    jq -e '.["openai-codex"].access == "codex-at"' "$HOME/.pi/agent/auth.json"
    test "$(cat "$HOME/.pi/agent/auth-probe")" = "OPENCODE_API_KEY="

    # A non-object fragment must fail loudly and leave auth.json untouched.
    home2="$TMPDIR/home2"
    mkdir -p "$home2/.pi/agent"
    printf '%s\n' '{"openai-codex":{"type":"oauth","access":"codex-at"}}' >"$home2/.pi/agent/auth.json"
    if HOME="$home2" ${authWrapper badAuthFragment}/bin/pi; then
      echo "pi: non-object auth fragment was accepted (expected failure)" >&2
      exit 1
    fi
    test "$(jq -r 'has("cerebras")' "$home2/.pi/agent/auth.json")" = "false"
    touch "$out"
  '';
in

assert selectedPi == upstreamPi.override { useBun = false; };
assert lib.count (package: package == backgroundBashPin) configuredPluginPackages == 1;
assert backgroundBashConfig.shortcut == "ctrl+shift+b";
assert nonoPi != null;

{
  inherit
    authMergeSmoke
    backgroundBashSmoke
    nonoSmoke
    runtimeSmoke
    ;
}
