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

/** Manual zoom bounds as multipliers of natural size. */
export const MIN_ZOOM = 0.1;
export const MAX_ZOOM = 5;
/** Multiplicative step used by Zoom in (Zoom out steps by its reciprocal). */
export const ZOOM_STEP = 1.25;

/**
 * Scale that fits a diagram into its frame. The cap bounds the enlargement:
 * the page itself never scales a diagram past natural size, while the
 * fullscreen modal lets it fill the panel. A zero-sized input falls back to 1
 * so a missing measurement never hides content.
 */
export function fitScale(naturalW, naturalH, frameWidth, frameHeight, cap = 1) {
  if (naturalW <= 0 || naturalH <= 0 || frameWidth <= 0 || frameHeight <= 0) return 1;
  return Math.min(frameWidth / naturalW, frameHeight / naturalH, cap);
}

/** Steps within the manual bounds without snapping up from a smaller fullscreen fit. */
export function stepScale(currentScale, factor) {
  const next = currentScale * factor;
  if (!Number.isFinite(next)) return currentScale;
  return Math.min(MAX_ZOOM, Math.max(Math.min(MIN_ZOOM, currentScale), next));
}
/** Sensitivity of ctrl/cmd + wheel zoom: how much scale each pixel of deltaY moves. */
export const WHEEL_ZOOM_SENSITIVITY = 0.003;

/**
 * Per-wheel-notch zoom level. Trackpads
 * fire many small events, so the factor is proportional to deltaY — a fixed
 * per-notch step would amplify momentum into wild swings.
 */
export function wheelScale(currentScale, deltaY) {
  if (!Number.isFinite(deltaY) || deltaY === 0) return currentScale;
  const factor = Math.exp(-deltaY * WHEEL_ZOOM_SENSITIVITY);
  return stepScale(currentScale, factor);
}
/**
 * Overflow state of a scroll container. Used to gate pan affordances and
 * cursors: a diagram can only be panned when its content exceeds the frame.
 */
export function isOverflowing({ scrollHeight, clientHeight, scrollWidth, clientWidth }) {
  return scrollHeight > clientHeight || scrollWidth > clientWidth;
}

/**
 * Whether a pointer-down on the diagram figure may start a pan. Drag that
 * starts on the SVG's text or outside the figure must never hijack selection.
 */
export function panStartAllowed({ insideFigure, insideText }) {
  return insideFigure && !insideText;
}

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
      await renderDiagram(renderer, diagram, signal);
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

async function renderDiagram(mermaid, diagram, signal) {
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
    if (!signal?.aborted) target.replaceWith(errorState(source, errorMessage(error)));
    return;
  }

  if (signal?.aborted) return;

  const figure = document.createElement("figure");
  figure.className = "smdg";
  figure.tabIndex = 0;
  figure.setAttribute("role", "group");
  figure.setAttribute("aria-label", "Diagram");
  // The SVG is not sanitized again: Mermaid sanitizes its own output at
  // securityLevel strict, and DOMPurify's HTML profile strips the
  // `foreignObject` labels most diagram types render their text into.
  figure.innerHTML = rendered.svg;

  // The controls live outside the scroll area: a zoomed diagram scrolls
  // beneath them instead of carrying them off-screen.
  const frame = document.createElement("div");
  frame.className = "smdg-frame";
  frame.append(figure);

  target.replaceWith(frame);
  bindInteractions(rendered.bindFunctions, figure);
  initDiagramZoom(frame, figure, signal);
}

/**
 * Fits the diagram to its frame and adds zoom, fit, and fullscreen controls.
 *
 * Zoom state belongs to the mounted figure, so a document load always starts
 * fitted. The observer re-fits when the frame changes width, while a scale the
 * reader chose by hand is left alone until Fit is pressed again.
 */
function initDiagramZoom(frame, figure, signal) {
  const svg = figure.querySelector("svg");
  if (!svg) return;

  const natural = naturalSize(svg);
  if (natural.width <= 0 || natural.height <= 0) return;

  const bar = document.createElement("div");
  bar.className = "smdg-controls";
  bar.setAttribute("role", "group");
  bar.setAttribute("aria-label", "Diagram controls");

  const expandButton = makeControlButton("Expand diagram", "Expand");
  expandButton.classList.add("smdg-expand");
  expandButton.setAttribute("aria-haspopup", "dialog");

  const zoomIn = makeControlButton("Zoom in diagram", "+");
  const zoomOut = makeControlButton("Zoom out diagram", "−");
  const fitButton = makeControlButton("Fit diagram", "Fit");
  fitButton.setAttribute("aria-pressed", "true");

  bar.append(zoomIn, zoomOut, fitButton, expandButton);
  frame.prepend(bar);

  let scale = 1;
  let fitted = true;

  // Background drag, panned by the scroll container: applied in applyScale
  // so fit and zoom changes keep the cursor honest.
  const pan = initDiagramPan(figure, signal);

  const applyScale = (next, { fit = false } = {}) => {
    scale = next;
    fitted = fit;
    // Floor the pixels: a fitted diagram must never overflow its content box by
    // a fraction of a pixel and grow a scrollbar it does not need.
    svg.style.width = `${Math.floor(natural.width * scale)}px`;
    svg.style.height = `${Math.floor(natural.height * scale)}px`;
    zoomIn.disabled = scale >= MAX_ZOOM;
    zoomOut.disabled = scale <= MIN_ZOOM;
    fitButton.setAttribute("aria-pressed", fit ? "true" : "false");
    pan.syncCursor();
  };

  const fitScaleNow = () => {
    const expanded = Boolean(frame.closest(".smdg-modal"));
    const bounds = frameBounds(figure, expanded);
    const next = fitScale(natural.width, natural.height, bounds.width, bounds.height, expanded ? MAX_ZOOM : 1);
    return expanded ? next : Math.max(MIN_ZOOM, next);
  };

  const applyFit = () => {
    figure.scrollLeft = 0;
    figure.scrollTop = 0;
    applyScale(fitScaleNow(), { fit: true });
  };

  zoomIn.addEventListener("click", () => applyScale(stepScale(scale, ZOOM_STEP)));
  zoomOut.addEventListener("click", () => applyScale(stepScale(scale, 1 / ZOOM_STEP)));
  fitButton.addEventListener("click", applyFit);

  // Ctrl/Cmd + wheel is the "zoom toward the chart" gesture: the same applyScale
  // keeps Fit's state and cursor honest. Plain wheel keeps native scrolling.
  figure.addEventListener("wheel", (event) => {
    if (!event.ctrlKey && !event.metaKey) return;
    event.preventDefault();
    applyScale(wheelScale(scale, event.deltaY));
  }, { passive: false });

  const observer = new ResizeObserver(() => {
    if (!fitted) return;

    const next = fitScaleNow();
    const width = Math.floor(natural.width * next);
    const height = Math.floor(natural.height * next);
    if (width !== Math.floor(natural.width * scale) || height !== Math.floor(natural.height * scale)) {
      applyScale(next, { fit: true });
    }
  });
  observer.observe(frame);
  signal?.addEventListener("abort", () => observer.disconnect(), { once: true });

  initFullscreen(frame, figure, expandButton, signal, () => {
    if (fitted) applyFit();
    else pan.syncCursor();
  });
  applyFit();
}

/**
 * Expands the existing frame without rendering or binding the diagram again.
 * A placeholder keeps the page in place while the dialog owns the frame.
 */
function initFullscreen(frame, figure, expandButton, signal, refit) {
  let close;

  expandButton.addEventListener("click", () => {
    if (close || signal?.aborted || !frame.isConnected) return;

    const dialog = document.createElement("dialog");
    dialog.className = "smdg-modal";
    dialog.setAttribute("aria-label", "Expanded diagram");

    const closeButton = makeControlButton("Close expanded diagram", "×");
    closeButton.classList.add("smdg-modal-close");
    closeButton.autofocus = true;

    const placeholder = document.createElement("div");
    placeholder.className = "smdg-frame smdg-placeholder";
    placeholder.style.height = `${frame.getBoundingClientRect().height}px`;
    const { scrollLeft, scrollTop } = figure;

    close = (restoreFocus = true) => {
      placeholder.replaceWith(frame);
      dialog.close();
      dialog.remove();
      close = undefined;

      if (!restoreFocus) return;
      refit();
      figure.scrollLeft = scrollLeft;
      figure.scrollTop = scrollTop;
      if (expandButton.isConnected) expandButton.focus({ preventScroll: true });
    };

    closeButton.addEventListener("click", () => close());
    dialog.addEventListener("cancel", (event) => {
      event.preventDefault();
      close();
    });
    dialog.addEventListener("click", (event) => {
      if (event.target === dialog) close();
    });

    frame.replaceWith(placeholder);
    dialog.append(closeButton, frame);
    document.body.append(dialog);
    dialog.showModal();
    refit();
    figure.scrollLeft = scrollLeft;
    figure.scrollTop = scrollTop;
  });

  signal?.addEventListener("abort", () => close?.(false), { once: true });
}

/**
 * Drag-to-pan for a zoomed diagram: grabbing the figure background (or any
 * non-text surface of the SVG) scrolls it. Text stays naturally selectable.
 * Only mouse and pen are handled — touch keeps native scrolling.
 *
 * Returns a sync function so zoom/fit can re-check the scroll affordance.
 */
function initDiagramPan(figure, signal) {
  const syncCursor = () => {
    figure.classList.toggle("smdg-pannable", isOverflowing(figure));
  };
  syncCursor();

  figure.addEventListener("pointerdown", (event) => {
    if (event.pointerType === "touch") return;
    if (event.button !== 0) return;
    if (!isOverflowing(figure)) return;

    const target = event.target;
    const insideFigure = figure.contains(target);
    const insideText = Boolean(target?.closest?.("text, tspan, foreignObject"));
    if (!panStartAllowed({ insideFigure, insideText })) return;

    event.preventDefault();
    figure.classList.add("smdg-dragging");
    const startX = event.clientX;
    const startY = event.clientY;
    const startLeft = figure.scrollLeft;
    const startTop = figure.scrollTop;

    // Window-level listeners keep the drag alive regardless of capture support.
    const onMove = (moveEvent) => {
      figure.scrollLeft = startLeft - (moveEvent.clientX - startX);
      figure.scrollTop = startTop - (moveEvent.clientY - startY);
    };
    const onEnd = () => {
      figure.classList.remove("smdg-dragging");
      window.removeEventListener("pointermove", onMove);
      window.removeEventListener("pointerup", onEnd);
      window.removeEventListener("pointercancel", onEnd);
      syncCursor();
    };

    window.addEventListener("pointermove", onMove);
    window.addEventListener("pointerup", onEnd, { once: true });
    window.addEventListener("pointercancel", onEnd, { once: true });
  });

  signal?.addEventListener("abort", () => {
    figure.classList.remove("smdg-pannable", "smdg-dragging");
  }, { once: true });

  return { syncCursor };
}

/**
 * Natural size of a rendered diagram. Mermaid writes the natural size as
 * `width`/`height` attributes, which keep their value once the element is
 * scaled, unlike its measured box.
 */
function naturalSize(svg) {
  const width = Number.parseFloat(svg.getAttribute("width"));
  const height = Number.parseFloat(svg.getAttribute("height"));
  if (width > 0 && height > 0) return { width, height };

  const rect = svg.getBoundingClientRect();
  return { width: rect.width, height: rect.height };
}

/** Room inside the frame: its content width and the height cap it enforces. */
function frameBounds(figure, expanded) {
  const style = getComputedStyle(figure);
  const padX = length(style.paddingLeft) + length(style.paddingRight);
  const padY = length(style.paddingTop) + length(style.paddingBottom);
  const borderY = length(style.borderTopWidth) + length(style.borderBottomWidth);
  const cap = parseFloat(style.maxHeight);

  return {
    width: figure.clientWidth - padX,
    // max-height counts the whole box when border-box, and the content box otherwise.
    height: expanded
      ? figure.clientHeight - padY
      : Number.isFinite(cap) && cap > 0
        ? Math.max(24, cap - (style.boxSizing === "border-box" ? padY + borderY : 0))
        : Number.POSITIVE_INFINITY,
  };
}

function length(value) {
  const parsed = Number.parseFloat(value);
  return Number.isFinite(parsed) ? parsed : 0;
}

/** Buttons inside the frame: native buttons keep keyboard activation free. */
function makeControlButton(ariaLabel, label) {
  const button = document.createElement("button");
  button.type = "button";
  button.className = "smdg-control";
  button.textContent = label;
  button.setAttribute("aria-label", ariaLabel);
  return button;
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
