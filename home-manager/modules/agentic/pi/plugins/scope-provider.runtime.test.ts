import { afterEach, beforeEach, expect, mock, test } from "bun:test";
import { createServer, type Server } from "node:http";
import {
  mkdtempSync,
  mkdirSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { basename, dirname, join } from "node:path";

const piPackageDir = process.env.PI_PACKAGE_DIR;
if (!piPackageDir)
  throw new Error("PI_PACKAGE_DIR must point to the packaged Pi runtime");
const piSubagentsDir = process.env.PI_SUBAGENTS_DIR;
if (!piSubagentsDir)
  throw new Error("PI_SUBAGENTS_DIR must point to pi-subagents 0.17.1");

const piDistDir =
  basename(piPackageDir) === "dist" ? piPackageDir : join(piPackageDir, "dist");
const packageScopeDir = dirname(dirname(piDistDir));
const piAi = await import(`${join(packageScopeDir, "pi-ai", "dist")}/index.js`);
const pi = await import(`${piDistDir}/index.js`);
const piTui = await import(
  `${join(packageScopeDir, "pi-tui", "dist")}/index.js`
);
mock.module("@earendil-works/pi-ai", () => piAi);
mock.module("@earendil-works/pi-coding-agent", () => pi);
mock.module("@earendil-works/pi-tui", () => piTui);
const { InMemoryCredentialStore, InMemoryModelsStore } = piAi;
const { ModelRegistry, ModelRuntime } = pi;
const { runAgent } = await import(`${piSubagentsDir}/dist/agent-runner.js`);
const { loadCustomAgents } = await import(
  `${piSubagentsDir}/dist/custom-agents.js`
);
const { registerAgents } = await import(
  `${piSubagentsDir}/dist/agent-types.js`
);

// A non-openai-completions api id that speaks the mock server's
// openai-completions wire: a target provider can carry a real non-
// openai-completions api yet still complete against the local SSE fixture.
const { registerApiProvider } = await import(
  `${join(packageScopeDir, "pi-ai", "dist")}/compat.js`
);
const oaiCompletionsApi = await import(
  `${join(packageScopeDir, "pi-ai", "dist")}/api/openai-completions.js`
);
registerApiProvider(
  {
    api: "mock-responses",
    stream: oaiCompletionsApi.stream,
    streamSimple: oaiCompletionsApi.streamSimple,
  },
  "scope-runtime-test",
);

type RequestRecord = { model: string; messages: unknown[] };
type ResponsePlan = { finishReason: string };
type ChildSession = InstanceType<typeof pi.AgentSession>;

let agentDir = "";
let cwd = "";
let server: Server;
let baseUrl = "";
let requests: RequestRecord[] = [];
let responsePlans: ResponsePlan[] = [];
let previousAgentDir: string | undefined;
let previousScope: string | undefined;

beforeEach(async () => {
  agentDir = mkdtempSync(join(tmpdir(), "scope-child-agent-"));
  cwd = mkdtempSync(join(tmpdir(), "scope-child-cwd-"));
  previousAgentDir = process.env.PI_CODING_AGENT_DIR;
  previousScope = process.env.PI_SCOPE;
  process.env.PI_CODING_AGENT_DIR = agentDir;
  process.env.PI_SCOPE = "first";
  delete (globalThis as Record<string, unknown>).__PI_SCOPE_SEQ__;
  delete (globalThis as Record<string, unknown>).activePreset;
  delete (globalThis as Record<string, unknown>).upgradedPreset;
  delete (globalThis as Record<string, unknown>).rewriteDisabled;
  requests = [];
  responsePlans = [];

  server = createServer((request, response) => {
    let raw = "";
    request.setEncoding("utf8");
    request.on("data", (chunk) => {
      raw += chunk;
    });
    request.on("end", () => {
      const body = JSON.parse(raw) as RequestRecord;
      requests.push({ model: body.model, messages: body.messages });
      const plan = responsePlans.shift();
      if (plan) {
        response.writeHead(200, {
          "content-type": "text/event-stream",
          "cache-control": "no-cache",
          connection: "keep-alive",
        });
        response.write(
          `data: ${JSON.stringify({ id: `response-${requests.length}`, object: "chat.completion.chunk", created: 1, model: body.model, choices: [{ index: 0, delta: {}, finish_reason: plan.finishReason }] })}\n\n`,
        );
        response.end("data: [DONE]\n\n");
        return;
      }
      response.writeHead(200, {
        "content-type": "text/event-stream",
        "cache-control": "no-cache",
        connection: "keep-alive",
      });
      response.write(
        `data: ${JSON.stringify({ id: `response-${requests.length}`, object: "chat.completion.chunk", created: 1, model: body.model, choices: [{ index: 0, delta: { role: "assistant", content: `answer-${requests.length}` }, finish_reason: null }] })}\n\n`,
      );
      response.write(
        `data: ${JSON.stringify({ id: `response-${requests.length}`, object: "chat.completion.chunk", created: 1, model: body.model, choices: [{ index: 0, delta: {}, finish_reason: "stop" }] })}\n\n`,
      );
      response.end("data: [DONE]\n\n");
    });
  });
  await new Promise<void>((resolve) => server.listen(0, "127.0.0.1", resolve));
  const address = server.address();
  if (!address || typeof address === "string")
    throw new Error("local SSE server did not bind a TCP port");
  baseUrl = `http://127.0.0.1:${address.port}/v1`;

  mkdirSync(join(agentDir, "extensions"), { recursive: true });
  mkdirSync(join(agentDir, "agents"), { recursive: true });
  const extensionSourcePath =
    process.env.PI_SCOPE_EXTENSION_SOURCE ??
    join(import.meta.dir, "scope-provider.ts");
  const extension = readFileSync(extensionSourcePath, "utf8").replaceAll(
    '"@earendil-works/pi-coding-agent"',
    `"${piDistDir}/index.js"`,
  );
  writeFileSync(join(agentDir, "extensions", "scope-provider.ts"), extension);
  writeSettings({ enabled: false, maxRetries: 0, baseDelayMs: 1 });
  writeFileSync(
    join(agentDir, "agents", "junior.md"),
    `---\nname: junior\ndescription: Scoped runtime child\nmodel: scoped/junior\nextensions: true\nskills: false\ntools: read\n---\nReturn a short answer.`,
  );
  writeFileSync(
    join(agentDir, "agents", "direct.md"),
    `---\nname: direct\ndescription: Direct runtime child\nmodel: local/concrete-direct\nextensions: true\nskills: false\ntools: read\n---\nReturn a short answer.`,
  );
  registerAgents(loadCustomAgents(cwd, true));
});

afterEach(async () => {
  await new Promise<void>((resolve) => server.close(() => resolve()));
  if (previousAgentDir === undefined) delete process.env.PI_CODING_AGENT_DIR;
  else process.env.PI_CODING_AGENT_DIR = previousAgentDir;
  if (previousScope === undefined) delete process.env.PI_SCOPE;
  else process.env.PI_SCOPE = previousScope;
  rmSync(agentDir, { recursive: true, force: true });
  rmSync(cwd, { recursive: true, force: true });
});

function writeSettings(retry: {
  enabled: boolean;
  maxRetries: number;
  baseDelayMs: number;
}): void {
  writeFileSync(
    join(agentDir, "settings.json"),
    JSON.stringify({
      compaction: { enabled: true, reserveTokens: 64, keepRecentTokens: 1 },
      branchSummary: { reserveTokens: 64 },
      retry,
      scopeProvider: {
        first: {
          main: { model: "local/concrete-main" },
          remap: {
            "scoped/junior": {
              model: "local/concrete-junior",
              thinking: "high",
            },
          },
        },
        second: {
          main: { model: "local/second-main" },
          remap: {
            "scoped/junior": { model: "local/second-junior", thinking: "low" },
          },
        },
      },
    }),
  );
}

function concreteModel(id: string) {
  return {
    id,
    name: id,
    reasoning: true,
    input: ["text"],
    contextWindow: 4096,
    maxTokens: 512,
    cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
  };
}

async function createParentRuntime() {
  const runtime = await ModelRuntime.create({
    credentials: new InMemoryCredentialStore(),
    modelsStore: new InMemoryModelsStore(),
    modelsPath: null,
    allowModelNetwork: false,
    refreshOnCreate: false,
  });
  const registry = new ModelRegistry(runtime);
  registry.registerProvider("local", {
    name: "Local SSE",
    baseUrl,
    api: "openai-completions",
    apiKey: "test-key",
    models: [
      concreteModel("concrete-main"),
      concreteModel("concrete-junior"),
      concreteModel("concrete-direct"),
      concreteModel("second-main"),
      concreteModel("second-junior"),
    ],
  });
  registry.registerProvider("scoped", {
    name: "Scoped",
    baseUrl,
    api: "openai-completions",
    apiKey: "local",
    models: [{ ...concreteModel("junior"), name: "scoped/junior" }],
  });
  return { runtime, registry };
}

function parentContext(registry: InstanceType<typeof ModelRegistry>) {
  return {
    cwd,
    model: registry.find("local", "concrete-main"),
    modelRegistry: registry,
    thinkingLevel: "medium",
    sessionManager: pi.SessionManager.inMemory(cwd),
    getSystemPrompt: () => "Parent system prompt",
  } as any;
}

const extensionApi = {
  exec: async () => ({ code: 1, stdout: "", stderr: "" }),
} as any;

async function runChild(type: "junior" | "direct") {
  const { runtime, registry } = await createParentRuntime();
  let child: ChildSession | undefined;
  const result = await runAgent(
    parentContext(registry),
    type,
    "initial request",
    {
      pi: extensionApi,
      cwd,
      configCwd: cwd,
      onSessionCreated: (session: ChildSession) => {
        child = session;
      },
    },
  );
  if (!child)
    throw new Error("runAgent did not expose its real child AgentSession");
  return { runtime, registry, child, result };
}

async function appendTurn(session: ChildSession, text: string): Promise<void> {
  await session.prompt(text);
}

async function runAutoCompaction(
  session: ChildSession,
  reason: "threshold" | "overflow",
): Promise<void> {
  const before = session.sessionManager
    .getEntries()
    .filter((entry: any) => entry.type === "compaction").length;
  const compacted = await (session as any)._runAutoCompaction(
    reason,
    reason === "overflow",
  );
  const compactions = session.sessionManager
    .getEntries()
    .filter((entry: any) => entry.type === "compaction");
  expect(compactions).toHaveLength(before + 1);
  expect(compactions.at(-1)).toMatchObject({
    type: "compaction",
    fromHook: true,
  });
  if (reason === "overflow") expect(compacted).toBe(true);
}

function requestModels(start = 0): string[] {
  return requests.slice(start).map(({ model }) => model);
}

async function waitForRequestCount(count: number): Promise<void> {
  const deadline = Date.now() + 2000;
  while (requests.length < count) {
    if (Date.now() >= deadline)
      throw new Error(`timed out waiting for ${count} requests`);
    await Bun.sleep(1);
  }
}

test("runAgent scoped child routes normal, all compaction triggers and tree summaries to its concrete target", async () => {
  const { child, result } = await runChild("junior");
  expect(result.failure).toBeUndefined();
  expect(child.model).toMatchObject({ provider: "scoped", id: "junior" });
  expect(requestModels()).toEqual(["concrete-junior"]);

  await appendTurn(child, "manual compaction material");
  const beforeManual = requests.length;
  await child.compact("manual focus");
  expect(requestModels(beforeManual).length).toBeGreaterThan(0);
  expect(
    requestModels(beforeManual).every((model) => model === "concrete-junior"),
  ).toBe(true);
  expect(child.sessionManager.getBranch().at(-1)).toMatchObject({
    type: "compaction",
    fromHook: true,
  });

  await appendTurn(child, "threshold compaction material one");
  await appendTurn(child, "threshold compaction material two");
  const beforeThreshold = requests.length;
  await runAutoCompaction(child, "threshold");
  expect(requestModels(beforeThreshold).length).toBeGreaterThan(0);
  expect(
    requestModels(beforeThreshold).every(
      (model) => model === "concrete-junior",
    ),
  ).toBe(true);

  await appendTurn(child, "overflow compaction material one");
  await appendTurn(child, "overflow compaction material two");
  const beforeOverflow = requests.length;
  await runAutoCompaction(child, "overflow");
  expect(requestModels(beforeOverflow).length).toBeGreaterThan(0);
  expect(
    requestModels(beforeOverflow).every((model) => model === "concrete-junior"),
  ).toBe(true);

  await appendTurn(child, "branch root");
  const branch = child.sessionManager.getBranch();
  const target = branch.find(
    (entry: any) => entry.type === "message" && entry.message.role === "user",
  )?.id;
  if (!target)
    throw new Error("child session did not retain a navigable user entry");
  await appendTurn(child, "abandoned branch with file facts");
  const beforeTree = requests.length;
  const navigation = await child.navigateTree(target, {
    summarize: true,
    customInstructions: "preserve branch details",
  });
  expect(navigation.cancelled).toBe(false);
  expect(requestModels(beforeTree).length).toBeGreaterThan(0);
  expect(
    requestModels(beforeTree).every((model) => model === "concrete-junior"),
  ).toBe(true);
  const summaryEntry = child.sessionManager
    .getBranch()
    .find((entry: any) => entry.type === "branch_summary");
  expect(summaryEntry).toMatchObject({
    type: "branch_summary",
    summary: `The user explored a different conversation branch before returning here.\nSummary of that exploration:\n\nanswer-${requests.length}`,
    details: { readFiles: [], modifiedFiles: [] },
    usage: {
      input: 0,
      output: 0,
      cacheRead: 0,
      cacheWrite: 0,
      totalTokens: 0,
      cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 },
    },
    fromHook: true,
  });
  expect(child.model).toMatchObject({ provider: "scoped", id: "junior" });
  expect(requests.map(({ model }) => model)).not.toContain("junior");
});

test("native retries preserve scoped compaction success and terminal outcomes without alias fallback", async () => {
  writeSettings({ enabled: true, maxRetries: 2, baseDelayMs: 1 });
  const retrySuccess = await runChild("junior");
  await appendTurn(retrySuccess.child, "retry success material");
  let before = requests.length;
  responsePlans.push({ finishReason: "network_error" });
  await retrySuccess.child.compact();
  expect(requestModels(before)).toEqual([
    "concrete-junior",
    "concrete-junior",
    "concrete-junior",
  ]);
  expect(retrySuccess.child.sessionManager.getBranch().at(-1)).toMatchObject({
    type: "compaction",
    fromHook: true,
  });

  const nonRetryable = await runChild("junior");
  await appendTurn(nonRetryable.child, "non-retryable material");
  before = requests.length;
  responsePlans.push({ finishReason: "content_filter" });
  await expect(nonRetryable.child.compact()).rejects.toThrow(
    "Compaction cancelled",
  );
  expect(requestModels(before)).toEqual(["concrete-junior"]);
  expect(
    nonRetryable.child.sessionManager
      .getEntries()
      .filter((entry: any) => entry.type === "compaction"),
  ).toEqual([]);

  const exhausted = await runChild("junior");
  await appendTurn(exhausted.child, "retry exhaustion material");
  before = requests.length;
  responsePlans.push(
    { finishReason: "network_error" },
    { finishReason: "network_error" },
    { finishReason: "network_error" },
  );
  await expect(exhausted.child.compact()).rejects.toThrow(
    "Compaction cancelled",
  );
  expect(requestModels(before)).toEqual([
    "concrete-junior",
    "concrete-junior",
    "concrete-junior",
  ]);
  expect(requestModels(before)).not.toContain("junior");

  writeSettings({ enabled: false, maxRetries: 2, baseDelayMs: 1 });
  const disabled = await runChild("junior");
  await appendTurn(disabled.child, "disabled retry material");
  before = requests.length;
  responsePlans.push({ finishReason: "network_error" });
  await expect(disabled.child.compact()).rejects.toThrow(
    "Compaction cancelled",
  );
  expect(requestModels(before)).toEqual(["concrete-junior"]);
});

test("aborting native scoped retry backoff cancels without another request", async () => {
  writeSettings({ enabled: true, maxRetries: 2, baseDelayMs: 10_000 });
  const { child } = await runChild("junior");
  await appendTurn(child, "abort retry material");
  const before = requests.length;
  responsePlans.push({ finishReason: "network_error" });

  const compacting = child.compact();
  await waitForRequestCount(before + 1);
  child.abortCompaction();

  await expect(compacting).rejects.toThrow("Compaction cancelled");
  expect(requestModels(before)).toEqual(["concrete-junior"]);
  expect(
    child.sessionManager
      .getEntries()
      .filter((entry: any) => entry.type === "compaction"),
  ).toEqual([]);
});

test("runAgent direct child retains native dispatch and scoped switch affects only new children", async () => {
  const direct = await runChild("direct");
  expect(direct.child.model).toMatchObject({
    provider: "local",
    id: "concrete-direct",
  });
  expect(requestModels()).toEqual(["concrete-direct"]);
  await appendTurn(direct.child, "direct compaction material");
  const beforeDirectCompact = requests.length;
  await direct.child.compact();
  expect(requestModels(beforeDirectCompact).length).toBeGreaterThan(0);
  expect(
    requestModels(beforeDirectCompact).every(
      (model) => model === "concrete-direct",
    ),
  ).toBe(true);
  expect(direct.child.sessionManager.getBranch().at(-1)).toMatchObject({
    type: "compaction",
    fromHook: false,
  });

  requests = [];
  const first = await runChild("junior");
  const runner = (first.child as any)._extensionRunner;
  const command = runner.getCommand("scope");
  if (!command) throw new Error("real child did not bind the scope command");
  await command.handler("second", runner.createCommandContext());
  expect(first.child.model).toMatchObject({ provider: "scoped", id: "junior" });

  const second = await runChild("junior");
  expect(second.child.model).toMatchObject({
    provider: "scoped",
    id: "junior",
  });
  expect(requestModels()).toEqual(["concrete-junior", "second-junior"]);
});

type CapturingServer = {
  baseUrl: string;
  bodies: Array<Record<string, unknown>>;
  close: () => Promise<void>;
};

let capturingServer: CapturingServer | undefined;

afterEach(async () => {
  if (capturingServer) {
    await capturingServer.close();
    capturingServer = undefined;
  }
});

// SSE server that records full request bodies so payload-level assertions can
// inspect the wire values (model, forced effort) rather than aliases.
async function startCapturingServer(): Promise<CapturingServer> {
  const bodies: Array<Record<string, unknown>> = [];
  const capturing = createServer((request, response) => {
    let raw = "";
    request.setEncoding("utf8");
    request.on("data", (chunk) => {
      raw += chunk;
    });
    request.on("end", () => {
      const body = JSON.parse(raw) as Record<string, unknown>;
      bodies.push(body);
      response.writeHead(200, {
        "content-type": "text/event-stream",
        "cache-control": "no-cache",
        connection: "keep-alive",
      });
      response.write(
        `data: ${JSON.stringify({ id: `response-${bodies.length}`, object: "chat.completion.chunk", created: 1, model: body.model, choices: [{ index: 0, delta: { role: "assistant", content: `answer-${bodies.length}` }, finish_reason: null }] })}\n\n`,
      );
      response.write(
        `data: ${JSON.stringify({ id: `response-${bodies.length}`, object: "chat.completion.chunk", created: 1, model: body.model, choices: [{ index: 0, delta: {}, finish_reason: "stop" }] })}\n\n`,
      );
      response.end("data: [DONE]\n\n");
    });
  });
  await new Promise<void>((resolve) => capturing.listen(0, "127.0.0.1", resolve));
  const address = capturing.address();
  if (!address || typeof address === "string")
    throw new Error("capturing SSE server did not bind a TCP port");
  return {
    baseUrl: `http://127.0.0.1:${address.port}/v1`,
    bodies,
    close: () => new Promise<void>((resolve) => capturing.close(() => resolve())),
  };
}

// scopeProvider presets whose reviewer target varies across presets.
function writeReviewerSettings(
  presets: Record<string, { main: string; reviewer: { model: string; thinking?: string } }>,
): void {
  writeFileSync(
    join(agentDir, "settings.json"),
    JSON.stringify({
      compaction: { enabled: true, reserveTokens: 64, keepRecentTokens: 1 },
      branchSummary: { reserveTokens: 64 },
      retry: { enabled: false, maxRetries: 0, baseDelayMs: 1 },
      scopeProvider: Object.fromEntries(
        Object.entries(presets).map(([name, preset]) => [
          name,
          {
            main: { model: preset.main },
            remap: { "scoped/reviewer": preset.reviewer },
          },
        ]),
      ),
    }),
  );
}

function writeReviewerAgent(): void {
  writeFileSync(
    join(agentDir, "agents", "reviewer.md"),
    `---\nname: reviewer\ndescription: Scoped reviewer runtime child\nmodel: scoped/reviewer\nextensions: true\nskills: false\ntools: read\n---\nReturn a short answer.`,
  );
  registerAgents(loadCustomAgents(cwd, true));
}

async function createReviewerRuntime(baseUrl: string, reviewerTargets: string[]) {
  const runtime = await ModelRuntime.create({
    credentials: new InMemoryCredentialStore(),
    modelsStore: new InMemoryModelsStore(),
    modelsPath: null,
    allowModelNetwork: false,
    refreshOnCreate: false,
  });
  const registry = new ModelRegistry(runtime);
  registry.registerProvider("local", {
    name: "Local SSE",
    baseUrl,
    api: "openai-completions",
    apiKey: "test-key",
    models: [
      concreteModel("concrete-main"),
      concreteModel("second-main"),
      ...reviewerTargets.map(concreteModel),
    ],
  });
  registry.registerProvider("scoped", {
    name: "Scoped",
    baseUrl,
    api: "openai-completions",
    apiKey: "local",
    models: [{ ...concreteModel("reviewer"), name: "scoped/reviewer" }],
  });
  return { runtime, registry };
}

async function runReviewerChild(registry: InstanceType<typeof ModelRegistry>) {
  let child: ChildSession | undefined;
  const result = await runAgent(
    parentContext(registry),
    "reviewer",
    "initial request",
    {
      pi: extensionApi,
      cwd,
      configCwd: cwd,
      onSessionCreated: (session: ChildSession) => {
        child = session;
      },
    },
  );
  if (!child)
    throw new Error("runAgent did not expose its real child AgentSession");
  return { child, result };
}

test("runAgent scoped reviewer child rewrites requests to the reviewer target without forcing effort", async () => {
  writeReviewerSettings({
    low: {
      main: "local/concrete-main",
      reviewer: { model: "local/reviewer-low", thinking: "xhigh" },
    },
  });
  writeReviewerAgent();
  process.env.PI_SCOPE = "low";
  const capturing = await startCapturingServer();
  capturingServer = capturing;
  const { registry } = await createReviewerRuntime(capturing.baseUrl, [
    "reviewer-low",
  ]);
  const { child, result } = await runReviewerChild(registry);
  expect(result.failure).toBeUndefined();
  expect(child.model).toMatchObject({ provider: "scoped", id: "reviewer" });
  expect(capturing.bodies).toHaveLength(1);
  expect(capturing.bodies[0].model).toBe("reviewer-low");
  // The preset entry's "thinking" is not injected into the payload: a non-main
  // scoped session gets no per-entry thinking override, so it runs at the
  // session's inherited native thinking level and that default reaches the
  // wire.
  expect(capturing.bodies[0].reasoning_effort).toBe("medium");
});

test("runAgent scoped reviewer children rewrite to the switched preset's reviewer target after /scope", async () => {
  writeReviewerSettings({
    low: { main: "local/concrete-main", reviewer: { model: "local/reviewer-low" } },
    high: {
      main: "local/second-main",
      reviewer: { model: "local/reviewer-high" },
    },
  });
  writeReviewerAgent();
  process.env.PI_SCOPE = "low";
  const capturing = await startCapturingServer();
  capturingServer = capturing;
  const first = await runReviewerChild(
    (
      await createReviewerRuntime(capturing.baseUrl, [
        "reviewer-low",
        "reviewer-high",
      ])
    ).registry,
  );
  expect(first.result.failure).toBeUndefined();
  expect(first.child.model).toMatchObject({ provider: "scoped", id: "reviewer" });
  expect(capturing.bodies).toHaveLength(1);
  expect(capturing.bodies[0].model).toBe("reviewer-low");
  // no forced entry: the session's default thinking level is what reaches the wire
  expect(capturing.bodies[0].reasoning_effort).toBe("medium");

  const runner = (first.child as any)._extensionRunner;
  const command = runner.getCommand("scope");
  if (!command) throw new Error("real child did not bind the scope command");
  await command.handler("high", runner.createCommandContext());
  expect(first.child.model).toMatchObject({ provider: "scoped", id: "reviewer" });

  const second = await runReviewerChild(
    (
      await createReviewerRuntime(capturing.baseUrl, [
        "reviewer-low",
        "reviewer-high",
      ])
    ).registry,
  );
  expect(second.result.failure).toBeUndefined();
  expect(second.child.model).toMatchObject({ provider: "scoped", id: "reviewer" });
  expect(capturing.bodies).toHaveLength(2);
  expect(capturing.bodies[1].model).toBe("reviewer-high");
  expect(capturing.bodies[1].reasoning_effort).toBe("medium");
});

// Scope preset whose main target lives on a non-openai-completions api.
function writeCodexSettings(): void {
  writeFileSync(
    join(agentDir, "settings.json"),
    JSON.stringify({
      compaction: { enabled: true, reserveTokens: 64, keepRecentTokens: 1 },
      branchSummary: { reserveTokens: 64 },
      retry: { enabled: false, maxRetries: 0, baseDelayMs: 1 },
      scopeProvider: {
        codex: { main: { model: "codex/concrete-codex" }, remap: {} },
      },
    }),
  );
}

function writeCodexAgent(): void {
  writeFileSync(
    join(agentDir, "agents", "codex.md"),
    `---\nname: codex\ndescription: Scoped codex runtime child\nmodel: scoped/main\nextensions: true\nskills: false\ntools: read\n---\nReturn a short answer.`,
  );
  registerAgents(loadCustomAgents(cwd, true));
}

async function createCodexRuntime(baseUrl: string) {
  const runtime = await ModelRuntime.create({
    credentials: new InMemoryCredentialStore(),
    modelsStore: new InMemoryModelsStore(),
    modelsPath: null,
    allowModelNetwork: false,
    refreshOnCreate: false,
  });
  const registry = new ModelRegistry(runtime);
  registry.registerProvider("local", {
    name: "Local SSE",
    baseUrl,
    api: "openai-completions",
    apiKey: "test-key",
    models: [concreteModel("concrete-main")],
  });
  registry.registerProvider("codex", {
    name: "Codex SSE",
    baseUrl,
    api: "mock-responses",
    apiKey: "codex-key",
    models: [concreteModel("concrete-codex")],
  });
  registry.registerProvider("scoped", {
    name: "Scoped",
    baseUrl,
    api: "openai-completions",
    apiKey: "local",
    models: [{ ...concreteModel("main"), name: "scoped/main" }],
  });
  return { runtime, registry };
}

async function runCodexChild(registry: InstanceType<typeof ModelRegistry>) {
  let child: ChildSession | undefined;
  const result = await runAgent(
    parentContext(registry),
    "codex",
    "initial request",
    {
      pi: extensionApi,
      cwd,
      configCwd: cwd,
      onSessionCreated: (session: ChildSession) => {
        child = session;
      },
    },
  );
  if (!child)
    throw new Error("runAgent did not expose its real child AgentSession");
  return { child, result };
}

test("runAgent scoped main child on a non-openai-completions target resolves to the concrete model", async () => {
  writeCodexSettings();
  writeCodexAgent();
  process.env.PI_SCOPE = "codex";
  const capturing = await startCapturingServer();
  capturingServer = capturing;
  const { registry } = await createCodexRuntime(capturing.baseUrl);
  const { child, result } = await runCodexChild(registry);
  expect(result.failure).toBeUndefined();
  expect(child.model).toMatchObject({ provider: "scoped", id: "main" });
  expect(capturing.bodies).toHaveLength(1);
  // The target provider's api is not openai-completions: the scoped alias
  // must still resolve through the provider hook and reach the wire as the
  // concrete id.
  expect(capturing.bodies[0].model).toBe("concrete-codex");
});

// A runtime whose local + scoped providers point at the capturing server so
// raw-completion bodies can be inspected at the wire.
async function createMainRuntime(baseUrl: string) {
  const runtime = await ModelRuntime.create({
    credentials: new InMemoryCredentialStore(),
    modelsStore: new InMemoryModelsStore(),
    modelsPath: null,
    allowModelNetwork: false,
    refreshOnCreate: false,
  });
  const registry = new ModelRegistry(runtime);
  registry.registerProvider("local", {
    name: "Local SSE",
    baseUrl,
    api: "openai-completions",
    apiKey: "test-key",
    models: [concreteModel("concrete-main"), concreteModel("concrete-junior")],
  });
  registry.registerProvider("scoped", {
    name: "Scoped",
    baseUrl,
    api: "openai-completions",
    apiKey: "local",
    models: [
      { ...concreteModel("main"), name: "scoped/main" },
      { ...concreteModel("junior"), name: "scoped/junior" },
    ],
  });
  return { runtime, registry };
}

// Fire the extension's session_start (commits the registration and binds the
// process registry) without running a full agent turn.
async function startScopedSession(registry: InstanceType<typeof ModelRegistry>) {
  let child: ChildSession | undefined;
  await runAgent(
    parentContext(registry),
    "junior",
    "initial request",
    {
      pi: extensionApi,
      cwd,
      configCwd: cwd,
      onSessionCreated: (session: ChildSession) => {
        child = session;
      },
    },
  );
  if (!child)
    throw new Error("runAgent did not expose its real child AgentSession");
  return child;
}

function rawCompletionContext(): Record<string, unknown> {
  return {
    systemPrompt: "Answer concisely.",
    messages: [
      { role: "user", content: [{ type: "text", text: "Say ok" }], timestamp: Date.now() },
    ],
  };
}

test("raw modelRegistry.complete and streamSimple resolve scoped/main to the concrete target", async () => {
  const capturing = await startCapturingServer();
  capturingServer = capturing;
  const { runtime, registry } = await createMainRuntime(capturing.baseUrl);
  await startScopedSession(registry);

  const mainModel = registry.find("scoped", "main");
  expect(mainModel?.provider).toBe("scoped");
  expect(mainModel?.id).toBe("main");

  // Raw completion: ModelRegistry.complete must reach the wire as the concrete
  // id, not the alias, and inherit no effort or chat-template injection.
  const beforeComplete = capturing.bodies.length;
  const completed = await registry.complete(mainModel, rawCompletionContext(), {
    maxTokens: 64,
  });
  expect(completed.stopReason).not.toBe("error");
  const completeBody = capturing.bodies[beforeComplete];
  expect(completeBody.model).toBe("concrete-main");
  expect(completeBody).not.toHaveProperty("reasoning_effort");
  expect(completeBody).not.toHaveProperty("chat_template_kwargs");

  // Direct streamSimple: the raw ModelRuntime stream path (the one pi-ai and
  // web-access use) routes through the same provider-hook resolution.
  const beforeStream = capturing.bodies.length;
  const stream = runtime.streamSimple(mainModel, rawCompletionContext(), {});
  const drained = await stream.result();
  expect(drained.stopReason).not.toBe("error");
  const streamBody = capturing.bodies[beforeStream];
  expect(streamBody.model).toBe("concrete-main");
  expect(streamBody).not.toHaveProperty("reasoning_effort");
  expect(streamBody).not.toHaveProperty("chat_template_kwargs");

  // No raw request ever carries the alias id.
  expect(capturing.bodies.slice(beforeComplete).map((b) => b.model)).not.toContain(
    "main",
  );
});
