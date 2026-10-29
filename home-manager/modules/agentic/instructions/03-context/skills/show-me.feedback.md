# Shared text feedback

## Context

`feedback.js` and `feedback.css` add section and selected-passage comments to a text-heavy show-me artifact. Use them when the user is reviewing prose and expects their comments back as text. Ordinary explanatory visuals keep their own choice controls and get no feedback UI.

The component owns the selection affordance, the comment popover, the drawer, and browser-local drafts. It never writes to the artifact's content.

## Instructions

### Add it with one line

The show-me server publishes the assets under its reserved `/_show-me/` namespace, so nothing is copied:

```html
<script type="module" src="/_show-me/feedback-auto.js"></script>
```

That mounts the component over the page's `main` element, or the body when there is none. It loads its own stylesheet, uses the page path as the comment source, and stores drafts per page. No host script is needed.

### Mark the sections (optional)

Add `data-target-id` to each region the user may comment on, plus `data-target-label` when the id is not readable:

```html
<section data-target-id="rollout" data-target-label="Rollout plan">
  <h2>Rollout plan</h2>
</section>
```

* The label falls back to the region's first heading, then to the id. Choose ids that survive content edits, because stored comments keep them.
* Selecting text inside a marked region comments on that passage; selecting the region's heading comments on the region itself, with the heading as the quote.
* Without marked regions the whole page is one target, which suits a short artifact. Prose outside every marked region cannot be commented on.
* Set `data-smfb-artifact` on `<body>` when sibling pages belong to one review and should share drafts. Add `data-smfb-root` to narrow the annotatable text to one element instead of `main` or the body.

### Drive it explicitly instead

Use the controller API when the artifact swaps documents without a reload, owns its own comment count or drawer chrome, or needs a callback to return to a commented region:

```js
import { mountFeedback } from "/_show-me/feedback.js";

const feedback = mountFeedback({
  root: document.querySelector("main"),
  artifact: "release-notes",
  title: "Comments",
  onNavigate: ({ targetId }) => scrollToTarget(targetId),
});

feedback.setTargets([{ id, label, sourceId, sourceLabel, element }]);
```

The controller exposes `registerTarget`, `unregisterTarget`, `setTargets`, `getComments`, `openSectionComment(targetId, anchor?)`, `openDrawer`, `closeDrawer`, `isPersistent`, and `destroy`.

### Comment handoff

* Copy all writes grouped plain text to the clipboard. Ask the user to paste it into the chat; there is no submission endpoint.
* When the clipboard is unavailable, the component shows the same text in a selectable box. Leave that fallback in place.
* `isPersistent()` reports whether drafts reach browser storage. Warn the user before an in-page navigation would discard comments when it returns `false`.
