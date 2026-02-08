# UX Principles

Core UX design principles for the Logger viewer application.

## Design Philosophy

Logger is a **developer tool for extended use**. The UI is optimized for long sessions of log monitoring — low visual fatigue, high information density, and minimal friction.

### 1. Information Density Over Decoration

Every pixel should convey information. No decorative elements, gradients, or shadows. Use whitespace and color to separate content, not borders or boxes.

- Log lines are compact: 12dp mono font, 1.35× line height
- Metadata (timestamps, source) uses smaller 10dp type
- Badges use 9dp text with tight padding

### 2. Dark-First, Low-Saturation

The entire UI uses a dark theme inspired by Ayu Dark's warm, low-saturation palette. This reduces eye strain during extended debugging sessions.

- Background layers progress from `#0B0E14` (deepest) to `#252C3A` (active)
- Text uses warm off-white (`#D4CCBA`) instead of pure white
- Severity colors are the primary source of visual contrast

### 3. Severity is the Primary Visual Signal

Log severity drives the most prominent visual encoding — a colored bar on the left edge of every entry. Users should be able to scan error patterns at a glance.

| Severity | Bar Color | Purpose |
|----------|-----------|---------|
| Debug | `#636D83` | Muted gray — noise reduction |
| Info | `#7EB8D0` | Calm blue — normal flow |
| Warning | `#E6B455` | Amber — attention needed |
| Error | `#E06C60` | Red — problem detected |
| Critical | `#D94F68` | Hot pink — immediate action |

### 4. Responsive Without Breakpoints

The viewer adapts to three size modes via `LayoutBuilder`:

| Mode | Width | Behavior |
|------|-------|----------|
| Widget | 240–400dp | Minimal chrome, icon-only controls |
| Compact | 401–700dp | Full header, single-column |
| Full | 701dp+ | Full header, optional side panels |

Transitions are instant — no animation between modes.

### 5. Auto-Scroll with Manual Override

The log list auto-scrolls to show the latest entries. When the user scrolls up to review history, auto-scroll pauses. A button appears to resume auto-scrolling. This balances real-time awareness with historical inspection.

### 6. Plugin-Driven Rendering

Custom content types are rendered by plugins, not hardcoded widgets. This keeps the core viewer simple and allows domain-specific rendering without core changes. See [Plugin API](../reference/plugin-api.md).

### 7. Sticky Pinning for Context

Important log entries (or group headers) can be marked `sticky: true`, causing them to pin to the viewport top when scrolled past. This provides persistent context while browsing related entries below.

## Typography

| Role | Font | Size | Weight |
|------|------|------|--------|
| Log content | JetBrains Mono | 12dp | Regular |
| Timestamps | JetBrains Mono | 10dp | Regular |
| UI chrome | Inter | 11dp | Medium |
| Badges | Inter | 9dp | Bold |

Both fonts are bundled as assets (OFL-licensed). No network font loading.

## Interaction Patterns

- **Click session** → filter log view to that session
- **Click severity badge** → toggle severity filter
- **Scroll up** → pause auto-scroll; "Jump to bottom" button appears
- **Ctrl+F / search bar** → smart text search with autocomplete
- **Collapse/expand groups** → toggle group bodies
