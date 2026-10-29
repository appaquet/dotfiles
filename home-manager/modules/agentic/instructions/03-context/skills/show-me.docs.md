# Docs viewer

## Context

`agentic-show-me-serve` chooses the experience from the requested path. Read this file when the user reviews Markdown documents through show-me.

## Instructions

### Modes

* `/` and directory URLs return a generated index with ordinary links to files and subdirectories. The index stays an index even when the directory holds `index.html`; link `/index.html` explicitly to open that file.
* Ordinary files are served unchanged with their own content type, so an HTML artifact keeps its CSS, scripts, and images.
* A `.md` or `.markdown` URL returns the docs reader: the live document, a left-hand tree of every readable Markdown file beneath the serving root, and shared comments. Adding `?raw=1` returns the plain source.

### Scope

* The serving root and its subdirectories are the whole review. Choose the smallest directory that covers the documents; every non-protected file beneath it is reachable without authentication.
* Hidden and dependency trees such as `.git`, `.env*`, and `node_modules` are excluded, as are `secrets`, `credentials`, and `keys` directories.
* Refreshing reflects edits and newly added or removed documents. There is no manifest to rebuild and no push update.

### Links and comments

* Document URLs are real URLs. Relative and root-relative links, directory links, and heading fragments behave normally; links to ordinary files leave the reader.
* Comments belong to the whole serving root and are keyed by root-relative document paths, so one review spans several documents. Drafts stay in that browser.
* Ask the user to use Copy all in the comments drawer and paste the result into the chat. There is no submission endpoint.
