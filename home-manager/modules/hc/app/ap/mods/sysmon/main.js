// System monitor: btop in a window over the current space, on that space's machine. Bound to a key through
// `mod.open:sysmon`, which opens this mod as an invisible launcher: with a monitor running it ends it, otherwise it
// starts btop through herdr-core and opens a window holding a title bar (this mod again, `role: "bar"`) above the
// btop terminal. The window closes itself when btop ends, so every way out (the key again, the title bar's ✕, `q`
// in btop) ends the program. The window doesn't get the keyboard: a click into btop gives it.

import { View, div } from "gpui-kit";
import { h_flex } from "gpui-base";
import { spaces, focused, hc, terminals, openOverlay, closeOverlay, notify, props, theme } from "herdr";

// This mod's folder name, so the window's title bar can be this mod.
const NAME = "sysmon";
// herdr-core terminal name of the monitor; unique among a machine's live terminals.
const TERMINAL = "sysmon";
const SIZE = 0.9;
const BAR_HEIGHT = 28;

export default class Sysmon extends View {
  init() {
    const p = props() ?? {};
    this.bar = p.role === "bar";
    // `herdr-app check` runs init too: only a key press, which opens this mod as an overlay, acts.
    if (this.bar || !p.overlay) return;
    toggle()
      .catch((e) => notify({ title: "System monitor failed", body: String(e?.message ?? e), level: "error" }))
      .finally(() => closeOverlay(p.overlay));
  }

  // A window also closes without btop ending (a layout switch, the app quitting): end it here.
  async close() {
    if (this.bar) await stop(props()?.address);
  }

  render() {
    if (!this.bar) return div();
    const t = theme();
    const { address, machine } = props() ?? {};
    return h_flex().id("sysmon-bar").size_full().px(10).gap(8).items_center().bg(t.chrome).text_size(12)
      .child(div().text_color(t.foreground).child("btop"))
      .child(div().flex_1().text_color(t.dim).child(machine ?? "This computer"))
      .child(div().id("sysmon-close").px(6).rounded(4).text_color(t.dim).hover((s) => s.bg(t.hover).text_color(t.foreground))
        .on_mouse_down("left", (_e, cx) => cx.stop_propagation())
        .on_click(() => { stop(address); })
        .child("✕"));
  }
}

// Ends every running monitor if there is one, else opens one for the focused space.
async function toggle() {
  const running = terminals().filter((t) => t.name === TERMINAL && t.state === "live");
  if (running.length) {
    await Promise.all(running.map((t) => stop(t.address)));
    return;
  }

  const space = spaces().find((s) => s.id === focused()?.space);
  const machine = space?.machine ?? null;
  const r = await hc(["run", "--bg", "--rm", "--json", "--no-parent", "--name", TERMINAL, ...(machine ? ["--on", machine] : []), "btop"]);
  if (r.code !== 0) throw new Error(r.stderr.trim() || `hc run exited with ${r.code}`);

  const { address } = JSON.parse(r.stdout);
  openOverlay({
    kind: "window", key: NAME, width: SIZE, height: SIZE,
    layout: { type: "column", children: [
      { type: "block", size: { px: BAR_HEIGHT }, content: { mod: NAME, props: { role: "bar", address, machine } } },
      { type: "block", content: { terminal: address } },
    ] },
  });
}

// Ends a monitor. With `--rm` the terminal is gone as soon as it ends, so `hc kill` answering "removed" is success.
async function stop(address) {
  if (address) await hc(["kill", "--json", address]);
}
