# Keyboard Shortcuts & Interactions

All keyboard shortcuts and mouse interactions available in the Logger viewer app.

---

## Navigation

| Shortcut | Action |
|----------|--------|
| **Alt + Scroll** | Scroll by exact log line height (28dp increments) for precise line-by-line navigation |
| **Scroll** | Standard smooth scrolling through the log list |

---

## Time Range Controls

Time range controls let you zoom and pan the visible time window in the log viewer.

### Keyboard

| Shortcut | Action |
|----------|--------|
| **Ctrl + Left** | Pan time range left by 10% of current range width |
| **Ctrl + Right** | Pan time range right by 10% of current range width |
| **Ctrl + Shift + Left** | Shrink time range by 20% (zoom in from left) |
| **Ctrl + Shift + Right** | Expand time range by 20% (zoom out from right) |
| **Ctrl + 0** | Reset time range to full session |
| **Home** | Reset time range to full session |

### Mouse (Log List)

| Interaction | Action |
|-------------|--------|
| **Ctrl + Scroll** | Zoom time range in/out centered on cursor position |

### Mouse (Minimap)

| Interaction | Action |
|-------------|--------|
| **Scroll** | Zoom time range in/out |
| **Shift + Scroll** | Pan time range left/right |
| **Double-click** | Reset to full time range |

---

## Sticky Management

Sticky entries are log entries pinned to the top of the viewport.

| Interaction | Action |
|-------------|--------|
| **Click close button** | Dismiss a single sticky entry |
| **Alt + Click close button** | Dismiss the entire sticky group (all entries in that group) |

---

## Layout

| Shortcut | Action |
|----------|--------|
| **Ctrl + M** | Toggle mini mode (compact title bar) |

---

## Selection

| Interaction | Action |
|-------------|--------|
| **Hold Shift** | Enter selection mode |
| **Click (in selection mode)** | Toggle entry selection |
| **Shift + Click** | Range select — select all entries between the last-clicked entry (anchor) and the clicked entry |

---

## State View

| Interaction | Action |
|-------------|--------|
| **Click state card** | Filter log list to entries that set this state key (applies `state:key` filter) |

---

## Quick Reference Card

```
Navigation
  Alt + Scroll          Line-by-line scroll (28dp)

Time Range (Keyboard)
  Ctrl + ←/→            Pan 10%
  Ctrl + Shift + ←/→    Expand/shrink 20%
  Ctrl + 0 / Home       Reset to full session

Time Range (Mouse)
  Ctrl + Scroll          Zoom (log list)
  Scroll on minimap      Zoom
  Shift + Scroll minimap Pan
  Double-click minimap   Reset

Sticky
  Click ✕                Dismiss one entry
  Alt + Click ✕          Dismiss entire group

Layout
  Ctrl + M               Toggle mini mode

Selection
  Hold Shift             Enter selection mode
  Click (selection)      Toggle entry select
  Shift + Click          Range select

State View
  Click state card       Filter by state key
```
