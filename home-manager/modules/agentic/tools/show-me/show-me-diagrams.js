/**
 * Mermaid diagram rendering for show-me artifacts and the docs reader.
 *
 * A host collects its diagram blocks with one call: a Markdown fence arrives as
 * a `language-mermaid` code block and authored HTML uses a `pre.mermaid` block.
 * The Mermaid build is fetched only when the root holds a diagram, and each
 * block renders on its own so one broken diagram never hides the others.
 */

const MERMAID_URL = "https://cdn.jsdelivr.net/npm/mermaid@12.3.0/dist/mermaid.esm.min.mjs";
const STYLESHEET_URL = "/_show-me/diagrams.css";
const BLOCK_SELECTOR = "pre.mermaid, code.language-mermaid";
const PROCESSED_ATTRIBUTE = "data-smdg";
const LOAD_FAILURE = "The diagram renderer could not be loaded. Check the connection and reload.";
const MOUNT_FAILURE = "Reload to try again.";

/**
 * Dark palette shared by the reader and artifacts. The values follow the
 * reader's paper, surface, text, and accent tokens so a diagram sits in the
 * page instead of looking like an embedded widget.
 */
const THEME_VARIABLES = {
  background: "transparent",
  primaryColor: "#132c31",
  primaryTextColor: "#e8edf4",
  primaryBorderColor: "#2dd4bf",
  secondaryColor: "#241d3d",
  secondaryTextColor: "#e8edf4",
  secondaryBorderColor: "#a78bfa",
  tertiaryColor: "#111827",
  tertiaryTextColor: "#e8edf4",
  tertiaryBorderColor: "#60a5fa",
  lineColor: "#9aa8bd",
  textColor: "#e8edf4",
  edgeLabelBackground: "#0f1420",
  fontFamily: "system-ui, -apple-system, Segoe UI, Roboto, sans-serif",
  fontSize: "14px",
};

/** Per-diagram-type setting that keeps a rendered SVG at its natural size. */
const NATURAL_WIDTH = { useMaxWidth: false };

let rendererPromise = null;
let sequence = 0;

/**
 * Render every Mermaid block inside `root`.
 *
 * The call resolves after all blocks are rendered or reported as broken, and it
 * never rejects: an unavailable renderer or a failed mount leaves the affected
 * blocks readable as source. `signal` cancels the work when the host replaces
 * the document the blocks belong to.
 */
export async function mountDiagrams(root = document, { signal } = {}) {
  const diagrams = collectDiagrams(root);
  if (diagrams.length === 0 || signal?.aborted) return;

  try {
    loadStylesheet();

    const renderer = await loadRenderer();
    if (signal?.aborted) return;

    if (!renderer) {
      reportUnavailable(diagrams, LOAD_FAILURE);
      return;
    }

    // Mermaid measures label text, so a font that arrives after rendering would
    // clip the labels it measured without.
    if (document.fonts?.ready) await document.fonts.ready;

    for (const diagram of diagrams) {
      if (signal?.aborted) return;
      await renderDiagram(renderer, diagram);
    }
  } catch {
    reportUnavailable(diagrams, MOUNT_FAILURE);
  }
}

/**
 * Diagram source paired with the element that owns its rendered output.
 *
 * A Markdown fence arrives as a code element inside a pre, so the pre owns the
 * block: replacing only the code would leave an empty pre around the figure.
 * One pre therefore yields one diagram even when it holds several marked code
 * elements.
 */
function collectDiagrams(root) {
  const diagrams = [];
  const seen = new Set();

  for (const block of root.querySelectorAll(BLOCK_SELECTOR)) {
    const target = block.closest("pre") ?? block;
    if (seen.has(target) || target.closest(`[${PROCESSED_ATTRIBUTE}]`)) continue;

    seen.add(target);
    diagrams.push({ source: (block.textContent ?? "").trim(), target });
  }

  return diagrams;
}

/** The Mermaid module, loaded once per document. */
async function loadRenderer() {
  if (rendererPromise === null) {
    rendererPromise = import(MERMAID_URL)
      .then((module) => {
        const mermaid = module.default ?? module;
        mermaid.initialize({
          startOnLoad: false,
          securityLevel: "strict",
          theme: "base",
          themeVariables: THEME_VARIABLES,
          // Diagrams keep their natural size: Mermaid otherwise scales an SVG
          // down to the container, which makes a wide graph's labels unreadable.
          // The container scrolls instead.
          flowchart: NATURAL_WIDTH,
          sequence: NATURAL_WIDTH,
          gantt: NATURAL_WIDTH,
          timeline: NATURAL_WIDTH,
          class: NATURAL_WIDTH,
          state: NATURAL_WIDTH,
          er: NATURAL_WIDTH,
          pie: NATURAL_WIDTH,
          quadrantChart: NATURAL_WIDTH,
          mindmap: NATURAL_WIDTH,
          // Mermaid otherwise injects its own "Syntax error" diagram into the
          // page; this module reports the failure in place of the block.
          suppressErrorRendering: true,
        });
        return mermaid;
      })
      .catch(() => {
        // The next mount retries, so a reconnect does not need a page reload.
        rendererPromise = null;
        return null;
      });
  }

  return rendererPromise;
}

async function renderDiagram(mermaid, diagram) {
  const { source, target } = diagram;

  if (source === "") {
    target.remove();
    return;
  }

  target.setAttribute(PROCESSED_ATTRIBUTE, "done");

  let rendered;
  try {
    rendered = await mermaid.render(`smdg-diagram-${++sequence}`, source);
  } catch (error) {
    target.replaceWith(errorState(source, errorMessage(error)));
    return;
  }

  const figure = document.createElement("figure");
  figure.className = "smdg";
  figure.tabIndex = 0;
  figure.setAttribute("role", "group");
  figure.setAttribute("aria-label", "Diagram");
  // The SVG is not sanitized again: Mermaid sanitizes its own output at
  // securityLevel strict, and DOMPurify's HTML profile strips the
  // `foreignObject` labels most diagram types render their text into.
  figure.innerHTML = rendered.svg;
  target.replaceWith(figure);
  bindInteractions(rendered.bindFunctions, figure);
}

/** Binds Mermaid's optional interactions without risking the rendered diagram. */
function bindInteractions(bind, figure) {
  if (typeof bind !== "function") return;

  try {
    bind(figure);
  } catch {
    // Interactions are optional; a failure leaves the rendered diagram in place.
  }
}

/** Replaces a block whose diagram could not be parsed, keeping its source. */
function errorState(source, detail) {
  const state = document.createElement("div");
  state.className = "smdg smdg-error";
  state.setAttribute("role", "note");

  const message = document.createElement("p");
  message.className = "smdg-error-message";
  message.textContent = "This diagram could not be rendered.";

  const reason = document.createElement("p");
  reason.className = "smdg-error-detail";
  reason.textContent = detail;

  const pre = document.createElement("pre");
  pre.className = "smdg-source";
  const code = document.createElement("code");
  code.textContent = source;
  pre.append(code);

  state.append(message, reason, pre);
  return state;
}

/** Explains every diagram a failed mount left in place. */
function reportUnavailable(diagrams, detail) {
  for (const diagram of diagrams) {
    // A diagram rendered before the failure keeps its figure.
    if (!diagram.target.isConnected) continue;

    diagram.target.setAttribute(PROCESSED_ATTRIBUTE, "unavailable");
    diagram.target.replaceWith(errorState(diagram.source, detail));
  }
}

function errorMessage(error) {
  const text = error instanceof Error ? error.message : String(error);
  const firstLine = text.split("\n").map((line) => line.trim()).find((line) => line !== "");
  return firstLine ?? "The diagram source could not be parsed.";
}

/** Injects the companion stylesheet once, so hosts include JavaScript only. */
function loadStylesheet() {
  if (document.querySelector("link[data-smdg-stylesheet]")) return;

  const link = document.createElement("link");
  link.rel = "stylesheet";
  link.href = STYLESHEET_URL;
  link.dataset.smdgStylesheet = "";
  document.head.append(link);
}
