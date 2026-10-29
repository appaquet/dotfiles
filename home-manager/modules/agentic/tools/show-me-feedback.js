/**
 * Shared text-feedback component for show-me artifacts and the docs reader.
 *
 * A host mounts one instance over an annotatable text root and registers the
 * targets a comment may belong to: a document, a section, or any authored text
 * region. The component owns selection capture, the comment popover, and the
 * feedback drawer, and never mutates the host document.
 */

const SCHEMA_VERSION = 1;
const CONTEXT_CHARS = 40;
const SELECTION_DELAY_MS = 250;
const STATUS_CLEAR_MS = 2000;
const STORAGE_PREFIX = "smfb:";
const EXCLUDED_TAGS = new Set(["BUTTON", "INPUT", "OPTION", "SELECT", "TEXTAREA"]);
const TEMPLATE = `
  <button class="smfb-launcher" type="button" data-smfb-ui aria-haspopup="dialog">
    <span class="smfb-launcher-label"></span><span class="smfb-badge">0</span>
  </button>
  <button class="smfb-add" type="button" data-smfb-ui>Comment</button>
  <div class="smfb-popover" role="dialog" aria-label="Add a comment" data-smfb-ui>
    <q class="smfb-quote"></q>
    <textarea class="smfb-input" placeholder="Your comment" aria-label="Your comment"></textarea>
    <div class="smfb-row">
      <span class="smfb-hint">Ctrl+Enter saves · Esc cancels</span>
      <button class="smfb-btn" type="button" data-act="popcancel">Cancel</button>
      <button class="smfb-btn smfb-primary" type="button" data-act="popsave">Save</button>
    </div>
  </div>
  <aside class="smfb-drawer" role="dialog" aria-modal="false" aria-hidden="true">
    <header>
      <h2 class="smfb-drawer-title"></h2>
      <button class="smfb-btn" type="button" data-act="closedrawer">Close</button>
    </header>
    <div class="smfb-list"></div>
    <footer class="smfb-footer">
      <button class="smfb-btn smfb-primary" type="button" data-act="copyall">Copy all</button>
      <button class="smfb-btn" type="button" data-act="clearall">Clear all</button>
      <span class="smfb-status" role="status"></span>
    </footer>
  </aside>
  <dialog class="smfb-dialog" data-smfb-ui aria-label="Copy comments">
    <p class="smfb-dialog-text">Copy this text and paste it in the chat.</p>
    <textarea class="smfb-input smfb-copy" readonly aria-label="Comments to copy"></textarea>
    <div class="smfb-row">
      <button class="smfb-btn" type="button" data-act="copydlgclose">Close</button>
    </div>
  </dialog>
`;

let instanceCount = 0;
let commentSequence = 0;

/**
 * Mount a feedback instance and return its public controller.
 *
 * `root` is the element holding annotatable text and may be a function when the
 * host swaps the annotated document. `artifact` scopes persisted drafts.
 */
export function mountFeedback(options = {}) {
  const getRoot = () => (typeof options.root === "function" ? options.root() : options.root);
  const title = options.title ?? "Feedback";
  const artifact = options.artifact ?? "artifact";
  const onCountChange = options.onCountChange ?? null;
  const onNavigate = options.onNavigate ?? null;
  const storage = options.storage ?? defaultStorage();

  const targets = new Map();
  const byElement = new Map();
  const comments = readDraft(storage, artifact);
  let persistent = storage !== null;
  let pending = null;
  let selectionTimer = 0;
  let statusTimer = 0;
  let editingId = null;
  let lastFocused = null;
  const controller = new AbortController();
  const listen = (target, type, handler) =>
    target.addEventListener(type, handler, { signal: controller.signal });

  const instanceId = `smfb-${(instanceCount += 1)}`;
  const wrapper = document.createElement("div");
  wrapper.className = "smfb";
  wrapper.innerHTML = TEMPLATE;
  (options.container ?? document.body).append(wrapper);

  const els = {
    launcher: wrapper.querySelector(".smfb-launcher"),
    launcherLabel: wrapper.querySelector(".smfb-launcher-label"),
    badge: wrapper.querySelector(".smfb-badge"),
    add: wrapper.querySelector(".smfb-add"),
    popover: wrapper.querySelector(".smfb-popover"),
    quote: wrapper.querySelector(".smfb-quote"),
    input: wrapper.querySelector(".smfb-input"),
    drawer: wrapper.querySelector(".smfb-drawer"),
    drawerTitle: wrapper.querySelector(".smfb-drawer-title"),
    list: wrapper.querySelector(".smfb-list"),
    status: wrapper.querySelector(".smfb-status"),
    copy: wrapper.querySelector(".smfb-copy"),
    dialog: wrapper.querySelector(".smfb-dialog"),
    copyAll: wrapper.querySelector('[data-act="copyall"]'),
    clearAll: wrapper.querySelector('[data-act="clearall"]'),
  };

  els.drawer.id = `${instanceId}-drawer`;
  els.input.id = `${instanceId}-input`;
  els.copy.id = `${instanceId}-copy`;
  els.launcherLabel.textContent = title;
  els.drawerTitle.textContent = title;
  els.launcher.setAttribute("aria-controls", els.drawer.id);
  els.launcher.setAttribute("aria-expanded", "false");

  // --- public controller ---

  function registerTarget(target) {
    if (!target?.id) throw new Error("A feedback target needs an id");
    const normalized = {
      id: target.id,
      label: target.label ?? target.id,
      sourceId: target.sourceId ?? target.id,
      sourceLabel: target.sourceLabel ?? target.label ?? target.id,
      element: target.element ?? null,
    };
    targets.set(normalized.id, normalized);
    if (normalized.element) byElement.set(normalized.element, normalized);
    return () => unregisterTarget(normalized.id);
  }

  function unregisterTarget(targetId) {
    const existing = targets.get(targetId);
    if (!existing) return;
    targets.delete(targetId);
    if (existing.element && byElement.get(existing.element) === existing) {
      byElement.delete(existing.element);
    }
  }

  function setTargets(list) {
    for (const targetId of [...targets.keys()]) unregisterTarget(targetId);
    for (const target of list ?? []) registerTarget(target);
  }

  function getComments() {
    return comments.map((comment) => ({ ...comment }));
  }

  function openSectionComment(targetId, anchor) {
    const target = targets.get(targetId);
    if (!target) return;
    const rect = (anchor ?? target.element)?.getBoundingClientRect();
    if (!rect) return;
    pending = {
      targetId: target.id,
      targetLabel: target.label,
      sourceId: target.sourceId,
      sourceLabel: target.sourceLabel,
      quote: "",
      prefix: "",
      suffix: "",
      anchorRect: rect,
    };
    hideAddButton();
    openPopover();
  }

  function openDrawer() {
    els.drawer.classList.add("smfb-open");
    els.drawer.setAttribute("aria-hidden", "false");
    els.launcher.setAttribute("aria-expanded", "true");
    els.drawer.querySelector('[data-act="closedrawer"]').focus();
  }

  function closeDrawer() {
    if (!els.drawer.classList.contains("smfb-open")) return;
    els.drawer.classList.remove("smfb-open");
    els.drawer.setAttribute("aria-hidden", "true");
    els.launcher.setAttribute("aria-expanded", "false");
    els.launcher.focus();
  }

  function destroy() {
    controller.abort();
    clearTimeout(selectionTimer);
    clearTimeout(statusTimer);
    wrapper.remove();
  }

  // --- selection capture ---

  function capturePending() {
    const selection = window.getSelection();
    if (!selection || selection.isCollapsed || selection.rangeCount === 0) return null;
    const range = selection.getRangeAt(0);
    const target = resolveTarget(range.startContainer, range.endContainer, {
      root: getRoot(),
      byElement,
    });
    if (!target) return null;
    const quote = normalizeSpace(range.toString());
    if (!quote) return null;
    return {
      targetId: target.id,
      targetLabel: target.label,
      sourceId: target.sourceId,
      sourceLabel: target.sourceLabel,
      quote,
      prefix: boundedContext(target.element, range, "prefix"),
      suffix: boundedContext(target.element, range, "suffix"),
      anchorRect: range.getBoundingClientRect(),
    };
  }

  function placeAddButton() {
    if (els.popover.style.display === "block") return;
    pending = capturePending();
    if (!pending) return hideAddButton();
    const rect = pending.anchorRect;
    const maxLeft = document.documentElement.clientWidth - 110;
    els.add.style.display = "block";
    els.add.style.top = `${window.scrollY + rect.bottom + 6}px`;
    els.add.style.left = `${Math.max(8, Math.min(window.scrollX + rect.left, window.scrollX + maxLeft))}px`;
  }

  function hideAddButton() {
    els.add.style.display = "none";
  }

  // --- popover ---

  function openPopover() {
    if (!pending) return;
    lastFocused = document.activeElement;
    const rect = pending.anchorRect;
    els.quote.textContent = pending.quote;
    els.quote.hidden = pending.quote === "";
    els.input.value = "";
    els.popover.style.display = "block";
    const maxLeft = document.documentElement.clientWidth - els.popover.offsetWidth - 8;
    els.popover.style.top = `${window.scrollY + rect.bottom + 8}px`;
    els.popover.style.left = `${Math.max(8, Math.min(window.scrollX + rect.left, window.scrollX + maxLeft))}px`;
    hideAddButton();
    els.input.focus();
  }

  function closePopover() {
    els.popover.style.display = "none";
    pending = null;
    const restore = lastFocused instanceof HTMLElement && document.contains(lastFocused);
    if (restore) lastFocused.focus();
  }

  function savePopover() {
    const text = els.input.value.trim();
    if (!text || !pending) return;
    comments.push(
      createComment({
        id: createCommentId(),
        ...pending,
        comment: text,
        createdAt: Date.now(),
      }),
    );
    persistDraft();
    renderFeedback();
    closePopover();
    window.getSelection()?.removeAllRanges();
  }

  function startEditing(commentId) {
    editingId = commentId;
    renderFeedback();
    const input = els.list.querySelector(".smfb-item-edit");
    input?.focus();
    input?.setSelectionRange(input.value.length, input.value.length);
  }

  function finishEditing(commentId, value) {
    const text = value.trim();
    const comment = comments.find((entry) => entry.id === commentId);
    if (!text || !comment) return;
    comment.comment = text;
    editingId = null;
    persistDraft();
    renderFeedback();
  }

  function cancelEditing() {
    editingId = null;
    renderFeedback();
  }

  function deleteComment(commentId) {
    const index = comments.findIndex((entry) => entry.id === commentId);
    if (index === -1) return;
    comments.splice(index, 1);
    if (editingId === commentId) editingId = null;
    persistDraft();
    renderFeedback();
  }

  function clearAll() {
    if (comments.length === 0) return;
    if (!window.confirm(`Delete all ${comments.length} comments?`)) return;
    comments.length = 0;
    editingId = null;
    persistDraft();
    renderFeedback();
  }

  function persistDraft() {
    if (!storage) {
      persistent = false;
      return;
    }
    try {
      storage.setItem(STORAGE_PREFIX + artifact, JSON.stringify({ v: SCHEMA_VERSION, comments }));
      persistent = true;
    } catch {
      persistent = false;
    }
    if (!persistent) showStatus("Not saved in this browser — copy comments before closing.");
  }

  function showStatus(message) {
    clearTimeout(statusTimer);
    els.status.textContent = message;
    if (!message) return;
    statusTimer = setTimeout(() => {
      els.status.textContent = "";
    }, STATUS_CLEAR_MS);
  }

  async function copyAll() {
    if (comments.length === 0) return;
    const text = formatExport(comments);
    try {
      await navigator.clipboard.writeText(text);
      showStatus("Copied");
      return;
    } catch {
      // The clipboard API needs a secure origin; plain internal HTTP does not provide one.
    }
    els.copy.value = text;
    els.dialog.showModal();
    els.copy.focus();
    els.copy.select();
    let copied = false;
    try {
      copied = document.execCommand("copy");
    } catch {
      // Unsupported: the selected text stays available for manual copying.
    }
    if (copied) {
      els.dialog.close();
      showStatus("Copied");
    }
  }

  // --- rendering ---

  function renderFeedback() {
    els.badge.textContent = String(comments.length);
    els.list.replaceChildren();
    if (comments.length === 0) {
      const empty = document.createElement("p");
      empty.className = "smfb-empty";
      empty.textContent = "No comments yet. Select text, then press Comment.";
      els.list.append(empty);
    }
    for (const comment of comments) els.list.append(renderItem(comment, editingId));
    els.copyAll.disabled = comments.length === 0;
    els.clearAll.disabled = comments.length === 0;
    if (onCountChange) onCountChange(comments.length);
  }

  // --- wiring ---

  // Selection changes cover mouse, keyboard and touch selection alike; the delay
  // lets a drag finish before the button moves.
  listen(document, "selectionchange", () => {
    clearTimeout(selectionTimer);
    selectionTimer = setTimeout(placeAddButton, SELECTION_DELAY_MS);
  });
  listen(els.add, "click", openPopover);
  listen(els.launcher, "click", () => {
    if (els.drawer.classList.contains("smfb-open")) closeDrawer();
    else openDrawer();
  });
  listen(wrapper, "click", (event) => {
    const action = event.target.closest("[data-act]")?.dataset.act;
    const item = event.target.closest(".smfb-item");
    if (action === "closedrawer") closeDrawer();
    if (action === "popcancel") closePopover();
    if (action === "popsave") savePopover();
    if (action === "copydlgclose") els.dialog.close();
    if (action === "copyall") copyAll();
    if (action === "clearall") clearAll();
    if (action === "edit") startEditing(item.dataset.id);
    if (action === "canceledit") cancelEditing();
    if (action === "saveedit") finishEditing(item.dataset.id, item.querySelector(".smfb-item-edit").value);
    if (action === "delete") deleteComment(item.dataset.id);
  });
  listen(els.input, "keydown", (event) => {
    if (event.key === "Enter" && (event.ctrlKey || event.metaKey)) {
      event.preventDefault();
      savePopover();
    }
    if (event.key === "Escape") {
      event.preventDefault();
      closePopover();
    }
  });
  listen(wrapper, "keydown", (event) => {
    const editor = event.target.closest?.(".smfb-item-edit");
    if (!editor) return;
    if (event.key === "Enter" && (event.ctrlKey || event.metaKey)) {
      event.preventDefault();
      finishEditing(editor.closest(".smfb-item").dataset.id, editor.value);
    }
    if (event.key === "Escape") {
      event.preventDefault();
      cancelEditing();
    }
  });
  listen(wrapper, "input", (event) => {
    const editor = event.target.closest?.(".smfb-item-edit");
    if (!editor) return;
    editor.closest(".smfb-item").querySelector('[data-act="saveedit"]').disabled =
      editor.value.trim() === "";
  });
  listen(document, "keydown", (event) => {
    if (event.key !== "Escape") return;
    if (els.popover.contains(document.activeElement)) return;
    if (document.activeElement?.closest?.(".smfb-item-edit")) return;
    closeDrawer();
  });
  listen(els.list, "click", (event) => {
    const link = event.target.closest("[data-source]");
    if (!link || !onNavigate) return;
    event.preventDefault();
    onNavigate({ sourceId: link.dataset.source, targetId: link.dataset.target });
  });

  renderFeedback();

  return {
    registerTarget,
    unregisterTarget,
    setTargets,
    getComments,
    openSectionComment,
    openDrawer,
    closeDrawer,
    destroy,
    isPersistent: () => persistent,
  };
}

/**
 * Find the single registered target containing both endpoints of a selection.
 *
 * Both endpoints must sit inside the annotated root and outside component UI or
 * form fields, so a drag that leaves the intended region is not annotatable.
 */
export function resolveTarget(startNode, endNode, { root, byElement }) {
  if (!root || !byElement) return null;
  const start = walkToRoot(startNode, root, byElement);
  const end = walkToRoot(endNode, root, byElement);
  if (!start.insideRoot || !end.insideRoot) return null;
  if (!start.target || start.target !== end.target) return null;
  return start.target;
}

/** True when a node belongs to feedback chrome or an interactive form field. */
export function isExcludedNode(node) {
  return node.dataset?.smfbUi !== undefined || EXCLUDED_TAGS.has(node.tagName ?? "");
}

/**
 * Build a stored comment record from captured selection context.
 *
 * `prefix` and `suffix` hold bounded text around the quote so a later reader can
 * tell repeated quotes apart; a whole-section comment keeps an empty quote.
 */
export function createComment({
  id,
  targetId,
  targetLabel,
  sourceId,
  sourceLabel,
  quote = "",
  prefix = "",
  suffix = "",
  comment,
  createdAt,
}) {
  return {
    v: SCHEMA_VERSION,
    id,
    sourceId,
    sourceLabel,
    targetId,
    targetLabel,
    quote,
    prefix,
    suffix,
    comment,
    createdAt,
  };
}

/** Comment identifiers stay unique when several are created in one millisecond. */
export function createCommentId(now = Date.now, random = Math.random) {
  commentSequence += 1;
  const salt = Math.floor(random() * 0x100000000).toString(36);
  return `smfb-${now().toString(36)}-${commentSequence.toString(36)}-${salt}`;
}

/**
 * Render comments as plain text grouped by source, ready to paste into a chat.
 *
 * Each source gets a heading, each comment an optional section label, the exact
 * quote as a quoted block, and the comment text.
 */
export function formatExport(comments) {
  const lines = ["Feedback"];
  for (const group of groupBySource(comments)) {
    const heading =
      group.sourceLabel && group.sourceLabel !== group.sourceId
        ? `${group.sourceLabel} (${group.sourceId})`
        : group.sourceId;
    lines.push("", `## ${heading}`);
    for (const comment of group.comments) {
      lines.push("");
      if (comment.targetLabel && comment.targetLabel !== comment.sourceLabel) {
        lines.push(`### ${comment.targetLabel}`, "");
      }
      if (comment.quote) {
        lines.push(...comment.quote.split("\n").map((line) => `> ${line}`), "");
      }
      lines.push(comment.comment);
    }
  }
  return `${lines.join("\n")}\n`;
}

/** Validate one stored comment, returning null for anything unusable. */
export function normalizeRecord(raw) {
  if (!raw || typeof raw !== "object" || raw.v !== SCHEMA_VERSION) return null;
  for (const key of ["id", "sourceId", "sourceLabel", "targetId", "targetLabel", "comment"]) {
    if (typeof raw[key] !== "string" || raw[key] === "") return null;
  }
  if (typeof raw.createdAt !== "number" || !Number.isFinite(raw.createdAt)) return null;
  for (const key of ["quote", "prefix", "suffix"]) {
    if (raw[key] !== undefined && typeof raw[key] !== "string") return null;
  }
  return createComment({
    id: raw.id,
    sourceId: raw.sourceId,
    sourceLabel: raw.sourceLabel,
    targetId: raw.targetId,
    targetLabel: raw.targetLabel,
    quote: raw.quote ?? "",
    prefix: raw.prefix ?? "",
    suffix: raw.suffix ?? "",
    comment: raw.comment,
    createdAt: raw.createdAt,
  });
}

/** Validate a stored draft payload, dropping entries that cannot be trusted. */
export function normalizeDraft(raw) {
  if (!raw || typeof raw !== "object" || raw.v !== SCHEMA_VERSION) return [];
  if (!Array.isArray(raw.comments)) return [];
  return raw.comments.map(normalizeRecord).filter(Boolean);
}

function groupBySource(comments) {
  const groups = [];
  for (const comment of comments) {
    let group = groups.find((entry) => entry.sourceId === comment.sourceId);
    if (!group) {
      group = {
        sourceId: comment.sourceId,
        sourceLabel: comment.sourceLabel,
        comments: [],
      };
      groups.push(group);
    }
    group.comments.push(comment);
  }
  return groups;
}

/**
 * Load the stored draft for one artifact, ignoring anything that cannot be trusted.
 *
 * A missing or unusable storage returns an empty list so the host keeps working.
 */
export function readDraft(storage, artifact) {
  if (!storage) return [];
  try {
    return normalizeDraft(JSON.parse(storage.getItem(STORAGE_PREFIX + artifact)));
  } catch {
    return [];
  }
}

function defaultStorage() {
  try {
    return globalThis.localStorage ?? null;
  } catch {
    return null;
  }
}

function renderItem(comment, editingId) {
  const item = document.createElement("article");
  item.className = "smfb-item";
  item.dataset.id = comment.id;

  const source = document.createElement("button");
  source.type = "button";
  source.className = "smfb-item-source";
  source.dataset.source = comment.sourceId;
  source.dataset.target = comment.targetId;
  source.textContent = comment.sourceLabel;
  item.append(source);

  if (comment.quote) {
    const quote = document.createElement("q");
    quote.className = "smfb-item-quote";
    quote.textContent = comment.quote;
    item.append(quote);
  }

  if (editingId === comment.id) {
    const editor = document.createElement("textarea");
    editor.className = "smfb-input smfb-item-edit";
    editor.id = `smfb-edit-${comment.id}`;
    editor.setAttribute("aria-label", "Edit comment");
    editor.value = comment.comment;
    item.append(editor, renderItemActions(comment, true));
    return item;
  }

  const text = document.createElement("p");
  text.className = "smfb-item-text";
  text.textContent = comment.comment;
  item.append(text, renderItemActions(comment, false));
  return item;
}

function renderItemActions(comment, editing) {
  const actions = document.createElement("div");
  actions.className = "smfb-item-actions";
  const buttons = editing
    ? [
        ["canceledit", "Cancel"],
        ["saveedit", "Save"],
      ]
    : [
        ["edit", "Edit"],
        ["delete", "Delete"],
      ];
  for (const [action, label] of buttons) {
    const button = document.createElement("button");
    button.type = "button";
    button.className = action === "saveedit" ? "smfb-item-act smfb-primary" : "smfb-item-act";
    button.dataset.act = action;
    button.textContent = label;
    if (action === "saveedit") button.disabled = comment.comment.trim() === "";
    actions.append(button);
  }
  return actions;
}

function walkToRoot(node, root, byElement) {
  let target = null;
  let current = node?.nodeType === 1 ? node : (node?.parentElement ?? null);
  while (current) {
    if (isExcludedNode(current)) return { insideRoot: false, target: null };
    if (!target && byElement.has(current)) target = byElement.get(current);
    if (current === root) return { insideRoot: true, target };
    current = current.parentElement;
  }
  return { insideRoot: false, target: null };
}

function boundedContext(element, range, side) {
  if (!element) return "";
  try {
    const probe = document.createRange();
    probe.selectNodeContents(element);
    if (side === "prefix") probe.setEnd(range.startContainer, range.startOffset);
    else probe.setStart(range.endContainer, range.endOffset);
    const text = normalizeSpace(probe.toString());
    return side === "prefix" ? text.slice(-CONTEXT_CHARS) : text.slice(0, CONTEXT_CHARS);
  } catch {
    return "";
  }
}

function normalizeSpace(text) {
  return String(text).replace(/\s+/g, " ").trim();
}
