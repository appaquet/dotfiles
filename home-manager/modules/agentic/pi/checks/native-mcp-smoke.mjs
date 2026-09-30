import assert from "node:assert/strict";
import {
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { createInterface } from "node:readline";
import { fileURLToPath, pathToFileURL } from "node:url";

const [packageDir, sourceDir, mode, pidPath, exitPath] = process.argv.slice(2);
if (mode === "--server") {
  serve(pidPath, exitPath);
} else {
  await run();
}

async function run() {
  const root = mkdtempSync(join(tmpdir(), "pi-native-mcp-"));
  process.env.HOME = root;
  process.env.PI_CODING_AGENT_DIR = join(root, "agent");
  process.env.PI_OFFLINE = "1";
  process.env.PI_SKIP_VERSION_CHECK = "1";
  process.env.HERDR_ENV = "0";
  process.env.PI_MODE = "orchestrator";
  delete process.env.PI_SCOPE;
  delete process.env.PI_NIX_SETTINGS_FILE;

  try {
    const sdk = await import(pathToFileURL(join(packageDir, "dist/index.js")));
    const ai = await import(
      pathToFileURL(
        join(packageDir, "node_modules/@earendil-works/pi-ai/dist/index.js"),
      )
    );
    for (const policy of ["soft", "hard"])
      await checkPolicy(root, policy, sdk, ai);
    console.log(
      "Native MCP/codemode smoke: connection, results, policies, timeouts, and shutdown passed",
    );
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
}

async function checkPolicy(root, policy, sdk, ai) {
  const cwd = join(root, policy);
  const agentDir = join(cwd, "agent");
  const pidFile = join(cwd, "server.pid");
  const exitFile = join(cwd, "server.closed");
  mkdirSync(agentDir, { recursive: true });
  process.env.PI_CODING_AGENT_DIR = agentDir;
  process.env.PI_ORCHESTRATOR_POLICY = policy;
  sdk.initTheme("dark", false);
  writeFileSync(
    join(agentDir, "settings.json"),
    JSON.stringify({ scopeProvider: {} }),
  );
  writeFileSync(
    join(agentDir, "mode-switch.json"),
    JSON.stringify({ orchestratorPolicy: policy }),
  );
  writeFileSync(
    join(agentDir, "bash-timeout.json"),
    JSON.stringify({ defaultTimeoutSeconds: 45, maxTimeoutSeconds: 90 }),
  );
  writeFileSync(join(cwd, "code.ts"), "original file body");
  writeFileSync(
    join(agentDir, "mcp.json"),
    JSON.stringify({
      mcpServers: {
        fixture: {
          command: process.execPath,
          args: [
            fileURLToPath(import.meta.url),
            packageDir,
            sourceDir,
            "--server",
            pidFile,
            exitFile,
          ],
          exposure: "codemode",
        },
      },
    }),
  );

  let nextCode;
  let callId = 0;
  const results = [];
  const errors = [];
  const localNames = [
    "bash-timeout",
    "herdr-agent-state",
    "mode-switch",
    "rpiv-herdr-bridge",
    "scope-provider",
    "settings-drift",
  ];
  const settingsManager = sdk.SettingsManager.inMemory({
    defaultProvider: "fixture",
    defaultModel: "fixed",
    compaction: { enabled: false },
    retry: { enabled: false },
    cacheWarming: "off",
  });
  const modelRuntime = await sdk.ModelRuntime.create({
    credentials: new ai.InMemoryCredentialStore(),
    modelsPath: null,
    modelsStorePath: join(agentDir, "models-cache.json"),
    refreshOnCreate: false,
  });
  const loader = new sdk.DefaultResourceLoader({
    cwd,
    agentDir,
    settingsManager,
    noSkills: true,
    noPromptTemplates: true,
    noThemes: true,
    noContextFiles: true,
    additionalExtensionPaths: localNames.map((name) =>
      join(sourceDir, "plugins", `${name}.ts`),
    ),
    extensionFactories: [
      {
        name: "codemode",
        builtin: true,
        replaceable: true,
        factory: sdk.createCodemodeExtension(),
      },
      {
        name: "mcp",
        builtin: true,
        replaceable: true,
        factory: sdk.createMcpExtension(),
      },
      (pi) => {
        pi.registerProvider("fixture", {
          api: "fixture-api",
          apiKey: "fixture-only-not-a-secret",
          baseUrl: "http://unused.invalid",
          models: [
            {
              id: "fixed",
              name: "Fixed test replies",
              reasoning: false,
              input: ["text"],
              contextWindow: 100000,
              maxTokens: 1024,
              cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
            },
          ],
          streamSimple(model) {
            const code = nextCode;
            nextCode = undefined;
            return reply(ai, model, code, ++callId);
          },
        });
        pi.on("tool_result", (event) => {
          results.push(structuredClone(event));
        });
      },
    ],
  });
  await loader.reload();
  assert.deepEqual(loader.getExtensions().errors, []);
  for (const name of localNames) {
    assert.ok(
      loader
        .getExtensions()
        .extensions.some(
          (extension) =>
            extension.path === join(sourceDir, "plugins", `${name}.ts`),
        ),
      `Local extension not loaded: ${name}`,
    );
  }
  const { session } = await sdk.createAgentSession({
    cwd,
    agentDir,
    modelRuntime,
    resourceLoader: loader,
    settingsManager,
    sessionManager: sdk.SessionManager.inMemory(cwd),
    thinkingLevel: "off",
  });
  session.extensionRunner.onError((error) => errors.push(error));

  async function script(code) {
    results.length = 0;
    nextCode = code;
    await session.prompt("Run the fixed fixture tool call.");
    assert.equal(nextCode, undefined, "Test provider was not invoked");
    const result = session.messages.findLast(
      (message) =>
        message.role === "toolResult" && message.toolName === "codemode",
    );
    assert.ok(result, "No codemode result in transcript");
    return result;
  }

  try {
    assert.equal(session.getActiveToolNames().includes("codemode"), false);
    await session.bindExtensions({});
    const model = modelRuntime.getModel("fixture", "fixed");
    assert.ok(model, "Fixed-reply provider did not register");
    await session.setModel(model);
    assert.equal(session.model.provider, "fixture");
    assert.equal(session.model.id, "fixed");
    await waitFor(
      () => session.getCallableToolNames().includes("mcp__fixture__echo"),
      "MCP fixture tool registration",
    );
    assert.equal(session.getActiveToolNames().includes("codemode"), true);
    assert.equal(
      session.getActiveToolNames().includes("mcp__fixture__echo"),
      false,
    );
    const mcp = loader
      .getExtensions()
      .extensions.find((extension) => extension.path === "builtin:mcp");
    assert.ok(mcp?.commands.has("mcp"), "Native MCP command did not load");

    const echo = await script(
      'const r = await tools.mcp__fixture__echo({value:"expected"}); if (r.isError || r.structuredContent.value !== "expected" || r.content[0].text !== "expected") throw new Error("Wrong MCP result"); text("MCP_RESULT_OK");',
    );
    assert.equal(echo.isError, false);
    assert.match(text(echo), /MCP_RESULT_OK/);
    assert.ok(
      results.some(
        (result) =>
          result.toolName === "mcp__fixture__echo" &&
          result.parentToolCallId === echo.toolCallId,
      ),
    );

    if (policy === "soft") {
      const read = await script(
        'await tools.read({path:"code.ts"}); text("READ_COMPLETE");',
      );
      assert.equal(read.isError, false);
      assert.match(text(read), /READ_COMPLETE/);
      const reminders = read.content.filter(
        (block) =>
          block.type === "text" &&
          block.text.startsWith("👑 Orchestrator mode:"),
      );
      assert.equal(
        reminders.length,
        1,
        "Soft reminder must appear once in outer output",
      );
      const child = results.find((result) => result.toolName === "read");
      assert.equal(child.parentToolCallId, read.toolCallId);
      assert.deepEqual(child.content, [
        { type: "text", text: "original file body" },
      ]);
    } else {
      await script(
        'await Promise.allSettled([tools.read({path:"code.ts"}), tools.write({path:"code.ts",content:"changed"}), tools.edit({path:"code.ts",oldText:"original",newText:"changed"})]); text("BLOCK_CHECK_COMPLETE");',
      );
      const blocked = session.messages.findLast(
        (message) =>
          message.role === "toolResult" && message.toolName === "codemode",
      );
      assert.deepEqual(
        blocked.details.calls.map((call) => [call.name, call.status]).sort(),
        [
          ["edit", "error"],
          ["read", "error"],
          ["write", "error"],
        ],
      );
      assert.equal(
        readFileSync(join(cwd, "code.ts"), "utf8"),
        "original file body",
      );
    }

    const bash = await script(
      'const r = await tools.bash({command:"printf fixture"}); text(r.output);',
    );
    assert.equal(bash.isError, false);
    const bashChild = results.find((result) => result.toolName === "bash");
    assert.equal(bashChild.input.timeout, 45);
    assert.deepEqual(bashChild.content, [{ type: "text", text: "fixture" }]);
    const excess = await script(
      'await tools.bash({command:"touch blocked-marker",timeout:91});',
    );
    assert.equal(excess.isError, true);
    assert.match(text(excess), /Bash timeout 91s exceeds the 90s ceiling/);
    assert.equal(existsSync(join(cwd, "blocked-marker")), false);
    assert.deepEqual(errors, []);
  } finally {
    // SDK callers deliver the shutdown event before disposing the session.
    await session.extensionRunner.emit({ type: "session_shutdown" });
    session.dispose();
    if (existsSync(pidFile)) {
      const pid = Number(readFileSync(pidFile, "utf8"));
      try {
        await waitFor(() => !alive(pid), "MCP fixture child shutdown");
        assert.equal(readFileSync(exitFile, "utf8"), "closed");
      } finally {
        if (alive(pid)) process.kill(pid, "SIGKILL");
      }
    }
  }
}

function reply(ai, model, code, id) {
  const stream = ai.createAssistantMessageEventStream();
  const message = {
    role: "assistant",
    api: model.api,
    provider: model.provider,
    model: model.id,
    timestamp: Date.now(),
    stopReason: code ? "toolUse" : "stop",
    content: code
      ? [
          {
            type: "toolCall",
            id: `fixture-${id}`,
            name: "codemode",
            arguments: { code },
          },
        ]
      : [{ type: "text", text: "Fixture complete" }],
    usage: {
      input: 0,
      output: 0,
      cacheRead: 0,
      cacheWrite: 0,
      totalTokens: 0,
      cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 },
    },
  };
  stream.push({ type: "start", partial: message });
  stream.push({ type: "done", reason: message.stopReason, message });
  return stream;
}

function serve(pidFile, exitFile) {
  writeFileSync(pidFile, String(process.pid));
  const input = createInterface({ input: process.stdin });
  const close = () => {
    writeFileSync(exitFile, "closed");
    process.exit(0);
  };
  input.on("close", close);
  process.on("SIGTERM", close);
  input.on("line", (line) => {
    const request = JSON.parse(line);
    if (request.id === undefined) return;
    let result;
    if (request.method === "initialize")
      result = {
        protocolVersion: request.params.protocolVersion,
        capabilities: { tools: {} },
        serverInfo: { name: "fixture", version: "1" },
      };
    else if (request.method === "tools/list")
      result = {
        tools: [
          {
            name: "echo",
            description: "Return the fixture value",
            inputSchema: {
              type: "object",
              properties: { value: { type: "string" } },
              required: ["value"],
            },
            outputSchema: {
              type: "object",
              properties: { value: { type: "string" } },
              required: ["value"],
            },
          },
        ],
      };
    else if (request.method === "tools/call")
      result = {
        content: [{ type: "text", text: request.params.arguments.value }],
        structuredContent: { value: request.params.arguments.value },
        isError: false,
      };
    else if (request.method === "ping") result = {};
    else {
      process.stdout.write(
        `${JSON.stringify({ jsonrpc: "2.0", id: request.id, error: { code: -32601, message: "Unsupported fixture method" } })}\n`,
      );
      return;
    }
    process.stdout.write(
      `${JSON.stringify({ jsonrpc: "2.0", id: request.id, result })}\n`,
    );
  });
}

function text(result) {
  return result.content
    .filter((block) => block.type === "text")
    .map((block) => block.text)
    .join("\n");
}

function alive(pid) {
  try {
    process.kill(pid, 0);
    return true;
  } catch (error) {
    if (error.code === "ESRCH") return false;
    throw error;
  }
}

async function waitFor(predicate, label) {
  const deadline = Date.now() + 10000;
  while (!predicate()) {
    if (Date.now() >= deadline)
      throw new Error(`Timed out waiting for ${label}`);
    await new Promise((resolve) => setTimeout(resolve, 25));
  }
}
