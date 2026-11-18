// Reading Claude usage payloads from the other machines. Both calls go through herdr-core's own machine
// connections, so nothing new is installed or authenticated: the app asks the core, the core asks the machine's
// long-lived `hc connect` process. The app API is imported here only, keeping sources.js loadable by the unit check.

import { exec, hc } from "herdr";
import { parseDump, sourceCommand, windowsOf } from "./sources.js";

// A read that has not answered by then is treated as failed; the core's own default is 30 s, far longer than a
// loop that cats a handful of small files.
const POLL_TIMEOUT = 8000;

// The machines a read can reach right now. Only `connected` can succeed — the core's other states are `connecting`,
// `needs_login` and `unreachable` — and temporary entries belong to a one-off session. The registry lists other
// machines only, never this one.
export async function pollableMachines() {
  try {
    const result = await hc(["machine", "ls", "--json"]);
    if (result.code !== 0) return [];

    return (JSON.parse(result.stdout).machines ?? [])
      .filter((machine) => !machine.temporary && machine.state === "connected")
      .map((machine) => machine.name);
  } catch {
    return [];
  }
}

// One round trip per machine. A machine that is gone, refuses the read or answers with nothing yields empty windows
// and a failed flag, so the caller keeps a report that source gave earlier instead of blanking it.
export async function fetchMachine(name) {
  try {
    const result = await exec("sh", ["-c", sourceCommand], { on: name, timeout: POLL_TIMEOUT });
    if (result.code !== 0) return { windows: {}, failed: true };

    return { windows: windowsOf(parseDump(result.stdout)) };
  } catch {
    return { windows: {}, failed: true };
  }
}
