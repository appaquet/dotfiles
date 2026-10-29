# Shared text feedback

## Context

`feedback.js` and `feedback.css` add section and selected-passage comments to a text-heavy show-me artifact. Use them when the user is reviewing prose and expects their comments back as text. Ordinary explanatory visuals keep their own choice controls and get no feedback UI.

The component owns the selection affordance, the comment popover, the drawer, and browser-local drafts. It never writes to the artifact's content.

## Instructions

### Load the assets

The show-me server publishes both assets under its reserved `/_show-me/` namespace, so no copying is needed:

```html
<link rel="stylesheet" href="/_show-me/feedback.css" />
<script type="module">
  import { mountFeedback } from "/_show-me/feedback.js";
</script>
```

### Mount and register targets

```js
const feedback = mountFeedback({
  root: document.querySelector("main"), // annotatable text root
  artifact: "release-notes", // one id per review; scopes saved drafts
  title: "Comments",
  onCountChange: (count) => updateCounter(count),
  onNavigate: ({ targetId }) => scrollToTarget(targetId),
});

feedback.setTargets([
  {
    id: "release-notes#rollout", // stable across edits
    label: "Rollout plan", // shown in the drawer and the export
    sourceId: "release-notes", // artifact or document identity
    sourceLabel: "Release notes", // what the agent reads in the export
    element: document.querySelector("#rollout"),
  },
]);
```

Add a host-owned control for whole-section comments; the component does not inject markup into annotated content:

```js
button.addEventListener("click", () => feedback.openSectionComment("release-notes#rollout", button));
```

### Identity

* Give every registered target a stable `id` that survives content edits. Selected-passage comments also store the original quote with bounded surrounding context, so never re-map a stored comment to new text.
* One `artifact` id per review. Drafts are stored under `smfb:<artifact>` and unrelated artifacts must not share one.
* Text outside a registered target, and any text inside the component's own UI or a form field, cannot be commented on.

### Comment handoff

* Copy all writes grouped plain text to the clipboard. Ask the user to paste it into the chat; there is no submission endpoint.
* When the clipboard is unavailable, the component shows the same text in a selectable box. Leave that fallback in place.
* `isPersistent()` reports whether drafts reach browser storage. Warn the user before an in-page navigation would discard comments when it returns `false`.

### Controller

`registerTarget`, `unregisterTarget`, `setTargets`, `getComments`, `openSectionComment(targetId, anchor?)`, `openDrawer`, `closeDrawer`, `isPersistent`, and `destroy`.
