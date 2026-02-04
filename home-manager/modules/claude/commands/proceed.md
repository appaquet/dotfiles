---
name: Proceed
description: Proceed with current workflow (universal gate)
---

# Proceed

🚀 Engage thrusters

Proceed with the current workflow. Clears any pending "Await /proceed" gate tasks and lets the
calling command continue.

For full implementation workflow (after `/ctx-plan`, `/proj-init`), use `/implement` instead.

## Task Tracking

| # | Subject | Description |
| --- | --- | --- |
| 1 | Clear gate tasks | Check TaskList for "Await /proceed" tasks, mark complete |

## Instructions

1. **Clear gate tasks** - Check `TaskList` for any "Await /proceed" tasks. Mark them completed.
   The calling workflow continues from where it left off.
