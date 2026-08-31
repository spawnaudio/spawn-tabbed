# One owner for focus: z-order, then recency, then none

"Which group does the user mean?" was re-derived at three call sites (keyboard shortcuts, strip z-order, auto-add targeting) from four signals — `NSWorkspace.frontmostApplication`, AX focused/main window, window-server z-order, and a `mostRecentGroup` side-channel. When another app grabs attention without showing a window (dock bounce, notification), the derivation returned nil and keyboard shortcuts silently died until the user clicked the visible app.

We decided: a single `FocusTracker` module owns the answer. The controller feeds it activation and AX focus events (push); reads are synchronous. Resolution policy, in order:

1. **Frontmost app's focused tab**: when the frontmost app is a grouped app and its cached focused window is that group's active tab, the answer comes from cache with no I/O.
2. **Z-order**: the group whose active window is highest in window-server z-order. Non-group windows — including the attention stealer's own window — do not participate: they cannot win, they only fail to block. The snapshot is queried at read time on this fallback path only (one `CGWindowList` call, hidden behind the interface).
3. **Recency**: the most recently focused group, updated only by push events (never by reads).
4. **None**: no group qualifies; shortcuts pass through.

## Considered options

- *Recency first*: simpler, but after a steal it can target a group the user can't see; z-order matches "the app I can visually see".
- *Re-derive on demand*: live AX/CGS queries per keypress, as before; rejected — the bug was in the signals, and per-keypress AX queries are the slow path.
- *Keyboard-only fix*: leaves the same stale derivation inside strip z-order and auto-add.

## Consequences

- The tracker's interface deals in value snapshots (window ids, pids), never live `AXUIElement`s — that is what makes the attention-steal regression testable in XCTest without a window server.
- Recency is updated on the push path only; `focusedGroupID()` is a pure read.
- Consumers must read focus only from the tracker; deriving it from `NSWorkspace` or AX at a call site is a regression.
