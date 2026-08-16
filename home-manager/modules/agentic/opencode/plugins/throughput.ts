// Per-assistant-message throughput tracker (TTFT, tok/s, latency, tokens, cost) that fires a TUI
// toast + opencode log when a session goes idle.
// 
// Taken from https://github.com/Howardzhangdqs/opencode-throughput
// But then heavily modified.

import type { Plugin } from "@opencode-ai/plugin"
import path from "path"
import fs from "fs"
import os from "os"

const XDG_DATA_HOME = process.env.XDG_DATA_HOME || path.join(os.homedir(), ".local", "share")
const LOG_DIR = path.join(XDG_DATA_HOME, "opencode", "log")
const LOG_FILE = path.join(LOG_DIR, "throughput.jsonl")

type LogEntry = {
  ts: string
  model: string
  providerID: string
  modelID: string
  sessionID: string
  messageID: string
  created_ms: number
  first_token_ms: number | null
  completed_ms: number
  ttft_ms: number | null
  tps: number | null
  latency_ms: number | null
  inputTokens: number
  outputTokens: number
  reasoningTokens: number
  cacheReadTokens: number
  cacheWriteTokens: number
  cost: number
  finish: string | undefined
}

type Aggregate = {
  calls: number
  ttftSum: number
  ttftCount: number
  latencySum: number
  tpsSum: number
  tpsCount: number
  input: number
  output: number
  reasoning: number
  cost: number
  cacheRead: number
  cacheWrite: number
}

// Tracks per-assistant-message throughput and maintains a per-session turn aggregate.
class ThroughputTracker {
  // fired per completed assistant message
  onEntry?: (entry: LogEntry) => void
  // fired on session.idle when the finishing turn had >= 1 call
  onIdle?: (sessionID: string, turn: Aggregate) => void

  private firstPartTime = new Map<string, number>()
  private turn = new Map<string, Aggregate>()
  // msgIDs already logged (prevents double-log if message.updated re-fires after completion)
  private processed = new Set<string>()
  // sessionID -> its messageIDs, so per-session cleanup (error/deleted) stays scoped
  private sessionMsgs = new Map<string, Set<string>>()

  handleEvent(event: { type: string; properties: any }) {
    if (event.type === "message.updated") {
      const info = event.properties.info as any
      if (info?.role !== "assistant") return

      const msgID = info.id as string
      this.trackMsg(info.sessionID as string | undefined, msgID)

      if (info.time?.completed) {
        if (this.processed.has(msgID)) return

        const created = info.time.created as number
        const completed = info.time.completed as number

        if (!created || !completed) {
          this.firstPartTime.delete(msgID)
          return
        }

        const latencyMs = completed - created
        const firstPart = this.firstPartTime.get(msgID)
        const ttftMs = firstPart ? firstPart - created : null
        const outputTokens = (info.tokens?.output as number) ?? 0
        const genTimeMs = firstPart ? completed - firstPart : latencyMs
        const tps = genTimeMs > 0 && outputTokens > 0 ? (outputTokens / genTimeMs) * 1000 : null

        // guard: NaN/Infinity (e.g. from the API) must not leak into the log or toast
        const rawCost = info.cost as number
        const cost = Number.isFinite(rawCost) ? rawCost : 0

        const providerID = (info.providerID as string) ?? ""
        const modelID = (info.modelID as string) ?? ""

        const entry: LogEntry = {
          ts: new Date().toISOString(),
          model: getModelKey(providerID, modelID),
          providerID,
          modelID,
          sessionID: info.sessionID as string,
          messageID: msgID,
          created_ms: created,
          first_token_ms: firstPart ?? null,
          completed_ms: completed,
          ttft_ms: ttftMs,
          tps,
          latency_ms: latencyMs,
          inputTokens: (info.tokens?.input as number) ?? 0,
          outputTokens,
          reasoningTokens: (info.tokens?.reasoning as number) ?? 0,
          cacheReadTokens: (info.tokens?.cache?.read as number) ?? 0,
          cacheWriteTokens: (info.tokens?.cache?.write as number) ?? 0,
          cost,
          finish: info.finish as string | undefined,
        }

        this.onEntry?.(entry)
        addToAggregate(this.aggregateFor(this.turn, entry.sessionID), entry)
        this.firstPartTime.delete(msgID)
        this.processed.add(msgID)
      }
    }

    if (event.type === "session.idle") {
      const sessionID = (event.properties as any).sessionID as string
      const t = this.turn.get(sessionID)
      if (sessionID && t && t.calls > 0) {
        this.turn.set(sessionID, freshAggregate())
        this.onIdle?.(sessionID, t)
      }
    }

    if (event.type === "message.part.updated") {
      const part = (event.properties as any).part as any
      if (!part) return

      const msgID = part.messageID as string
      this.trackMsg(part.sessionID as string | undefined, msgID)
      // first token of a thinking model is the reasoning part (before visible text);
      // use it so the decode window covers thinking + visible generation
      if ((part.type === "text" || part.type === "reasoning") && part.time?.start && !this.firstPartTime.has(msgID)) {
        this.firstPartTime.set(msgID, part.time.start)
      }
    }

    if (event.type === "message.removed") {
      const props = event.properties as any
      const msgID = props?.info?.id ?? props?.messageID
      if (msgID) {
        this.firstPartTime.delete(msgID as string)
        this.processed.delete(msgID as string)
      }
    }

    if (event.type === "session.error" || event.type === "session.deleted") {
      // scope to the affected session so a subagent error/deletion doesn't wipe other sessions
      const p = event.properties as any
      const sessionID = (p.sessionID ?? p.error?.sessionID ?? p.info?.sessionID) as string | undefined
      if (sessionID) this.dropSession(sessionID)
    }
  }

  private trackMsg(sessionID: string | undefined, msgID: string | undefined) {
    if (!sessionID || !msgID) return
    let set = this.sessionMsgs.get(sessionID)
    if (!set) {
      set = new Set()
      this.sessionMsgs.set(sessionID, set)
    }
    set.add(msgID)
  }

  private dropSession(sessionID: string) {
    const set = this.sessionMsgs.get(sessionID)
    if (set) {
      for (const m of set) {
        this.firstPartTime.delete(m)
        this.processed.delete(m)
      }
      set.clear()
    }
    this.sessionMsgs.delete(sessionID)
    this.turn.delete(sessionID)
  }

  private aggregateFor(map: Map<string, Aggregate>, sessionID: string): Aggregate {
    const existing = map.get(sessionID)
    if (existing) return existing
    const fresh = freshAggregate()
    map.set(sessionID, fresh)
    return fresh
  }
}

function freshAggregate(): Aggregate {
  return {
    calls: 0,
    ttftSum: 0,
    ttftCount: 0,
    latencySum: 0,
    tpsSum: 0,
    tpsCount: 0,
    input: 0,
    output: 0,
    reasoning: 0,
    cost: 0,
    cacheRead: 0,
    cacheWrite: 0,
  }
}

function addToAggregate(agg: Aggregate, entry: LogEntry) {
  agg.calls += 1
  if (entry.ttft_ms != null) {
    agg.ttftSum += entry.ttft_ms
    agg.ttftCount += 1
  }
  if (entry.latency_ms != null) agg.latencySum += entry.latency_ms
  if (entry.tps != null) {
    agg.tpsSum += entry.tps
    agg.tpsCount += 1
  }
  agg.input += entry.inputTokens
  agg.output += entry.outputTokens
  agg.reasoning += entry.reasoningTokens
  agg.cost += entry.cost
  agg.cacheRead += entry.cacheReadTokens
  agg.cacheWrite += entry.cacheWriteTokens
}

function getModelKey(providerID: string, modelID: string): string {
  return `${providerID}/${modelID}`
}

function formatNum(n: number | null): string {
  if (n == null) return "N/A"
  if (n >= 1000000) return (n / 1000000).toFixed(2) + "M"
  if (n >= 1000) return (n / 1000).toFixed(1) + "k"
  return n.toFixed(n >= 100 ? 0 : 1)
}

function formatMs(ms: number | null): string {
  if (ms == null) return "N/A"
  if (ms >= 60000) return (ms / 60000).toFixed(1) + "m"
  if (ms >= 1000) return (ms / 1000).toFixed(1) + "s"
  return ms.toFixed(0) + "ms"
}

function avg(sum: number, count: number): number | null {
  return count > 0 ? sum / count : null
}

// toast body: calls + latency + TTFT + tok/s + tokens + cost
function buildAggMsg(agg: Aggregate): string {
  const calls = `${agg.calls} call${agg.calls === 1 ? "" : "s"}`
  const parts = [
    calls,
    formatMs(agg.latencySum),
    "TTFT " + formatMs(avg(agg.ttftSum, agg.ttftCount)),
    formatNum(avg(agg.tpsSum, agg.tpsCount)) + " tok/s",
    "\u2191" + formatNum(agg.input) + " \u2193" + formatNum(agg.output) + " \u2193r" + formatNum(agg.reasoning),
    "cost $" + agg.cost.toFixed(4),
  ]
  return parts.join(" | ")
}

function ensureLogDir() {
  if (!fs.existsSync(LOG_DIR)) {
    fs.mkdirSync(LOG_DIR, { recursive: true })
  }
}

function appendLog(entry: LogEntry) {
  ensureLogDir()
  const line = JSON.stringify(entry) + "\n"
  fs.appendFileSync(LOG_FILE, line, "utf-8")
}

export const ThroughputPlugin: Plugin = async ({ client }) => {
  const tracker = new ThroughputTracker()

  tracker.onEntry = (entry) => appendLog(entry)

  tracker.onIdle = async (sessionID, turn) => {
    const logMsg = buildAggMsg(turn)

    try {
      await client.tui.showToast({
        body: {
          title: "Throughput",
          message: logMsg,
          variant: "info",
          duration: 10000,
        },
      })
    } catch { }

    try {
      await client.app.log({
        body: {
          service: "opencode-throughput",
          level: "info",
          message: logMsg,
          extra: {
            sessionID,
            calls: turn.calls,
            latency_ms: turn.latencySum,
            inputTokens: turn.input,
            outputTokens: turn.output,
            cost: turn.cost,
          },
        },
      })
    } catch { }
  }

  return {
    event: async ({ event }) => {
      tracker.handleEvent(event)
    },
  }
}

export default ThroughputPlugin
