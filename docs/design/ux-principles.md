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

Group headers automatically pin to the viewport top when their content is scrolled past ("sticky headers"). Users can also manually pin selected entries via the selection context menu. This provides persistent context while browsing related entries below.

## Typography

| Role | Font | Size | Weight |
|------|------|------|--------|
| Log content | JetBrains Mono | 12dp | Regular |
| Timestamps | JetBrains Mono | 10dp | Regular |
| UI chrome | Inter | 11dp | Medium |
| Badges | Inter | 9dp | Bold |

Both fonts are bundled as assets (OFL-licensed). No network font loading.

## Interaction Design

### 8. Hover Affordance Consistency

Every interactive element must communicate its clickability before the user clicks. This prevents "dead UI" syndrome where users can't distinguish interactive from inert elements.

- Pointer cursor (`SystemMouseCursors.click`) on all clickable elements — no exceptions
- Subtle brightness increase on hover via `Color.lerp(base, Colors.white, 0.04)`
- Smooth transitions using `TweenAnimationBuilder<Color?>` — 150ms for standard elements, 100ms for density-sensitive compact areas
- One shared pattern across all components — avoid per-widget hover reimplementation

### 9. Click Target Minimums

All interactive elements must have a minimum 32×28dp hit area, even when the visual element is smaller. Padding extends the clickable region invisibly. This ensures comfortable targeting on desktop displays without inflating visual density.

### 10. Filter Discovery

When a filter is programmatically activated (by clicking a tag, badge, or link rather than typing), the filter bar must become visible automatically. Active filters are indicated visually on their source elements (e.g., accent border on a filtered state tag). Users should never have hidden, invisible filter state — if something is filtering the view, it must be apparent.

### 11. Progressive Disclosure

Default to the most compact useful view. Reveal complexity on interaction:

- Mini mode is the default window state — compact companion, not a primary application
- Filter bar is hidden until a filter is active or the user focuses it
- Settings and panels slide out on demand and retract when dismissed
- Section details expand in-place rather than navigating to new views

### 12. Instant Response

Window-level operations (close, minimize, maximize, pin) must feel instantaneous. Use fire-and-forget for platform channel calls — update visual state optimistically before waiting for async confirmation. Users perceive even 100ms of delay on window chrome as sluggishness.

### 13. Scriptability

Support the `logger://` URI scheme for major operations (connect, filter, clear). CLI-oriented and automation-focused users integrate tools via scripts, Makefiles, CI annotations, and runbook links. Every action that can be triggered from the UI should eventually be expressible as a URI or command.

### 14. Connection Resilience

Reconnection must be silent and automatic. No toast spam during transient network failures. Only surface connection state changes that persist beyond one backoff cycle. The status bar is the single source of connection truth — never flash or flicker between states. This matters especially during rolling deploys where brief disconnects are expected.

### 15. Text Selection Priority

Log content text must be selectable with standard OS gestures: click-drag for range, double-click for word, triple-click for line. Interactive gestures (tap to expand, click to select row) must not interfere with text selection. Where selection and interaction conflict, wrap the interactive element with `SelectionContainer.disabled` to preserve selection on surrounding content.

## Interaction Patterns

- **Click session** → filter log view to that session
- **Click severity badge** → toggle severity filter
- **Click state tag** → add/remove filter for that state key; filter bar auto-shows
- **Scroll up** → pause auto-scroll; "Jump to bottom" button appears
- **Ctrl+F / search bar** → smart text search with autocomplete
- **Collapse/expand groups** → toggle group bodies
