# Tabbed

Tabbed turns any macOS windows into browser-style tabs: ⌘-drag one window onto another and the two share a frame and a floating strip. This context covers the whole app — it is a single, small utility.

## Language

**Tab group** (or **group**):
A set of real windows that share one frame and one strip. The unit of tabbing.
_Avoid_: stack, session

**Tab**:
One real OS window belonging to a group. Each tab is a live window of some app, not a view.
_Avoid_: window (ambiguous — many windows on screen belong to no group)

**Active tab**:
The tab currently occupying the group's frame. Exactly one per group.
_Avoid_: selected tab, current tab

**Hidden tab**:
A tab whose window is moved out of view because it is not the active tab. The window still exists; switching tabs brings it back.
_Avoid_: parked window, minimized tab (nothing is minimized)

**Strip**:
The floating pill that represents one group on screen, listing its tabs.
_Avoid_: tab bar (browser connotations), panel (that's the AppKit type)

**Compact mode**:
The strip reduced to a row of app icons, used when there is no room above the group's frame.
_Avoid_: mini mode, collapsed strip

**Focused group**:
The group the user means right now — the one keyboard shortcuts act on and whose strip sits above its window. Resolved from what the user can visually see, not from which app the system believes is active.
_Avoid_: frontmost group, most recent group (those are signals, not the concept)
