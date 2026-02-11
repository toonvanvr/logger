# Widget Development Prompt Template

## Instructions
Copy the prompt below and fill in the `[PLACEHOLDERS]`. Provide it alongside the widget idea description to an AI coding agent working on this codebase.

The prompt encodes everything learned from the HTTP Request Widget development session (Feb 2026): design patterns, theme tokens, plugin interfaces, house style, and anti-patterns.

---

## The Prompt

### Context

You are building a widget plugin for **Logger**, a real-time structured log viewer. Logger is a Flutter desktop app (Linux-first, AOT-compiled) that receives structured logs from a TypeScript client SDK over WebSocket. The client SDK sends `EventMessage` entries with a `widget` field containing a discriminated union payload (`WidgetPayload`).

**Architecture:** TypeScript client → Bun server (ring buffer) → WebSocket → Flutter desktop viewer → Plugin system → Renderer widget.

**Repository layout:**
- `packages/shared/src/widget.ts` — Zod schema for all widget types (source of truth)
- `packages/client/src/logger-builders.ts` — Client builder functions
- `packages/client/src/logger.ts` — Client SDK `Logger` class
- `app/lib/plugins/plugin_types.dart` — Plugin interfaces (RendererPlugin, FilterPlugin, etc.)
- `app/lib/plugins/plugin_registry.dart` — Plugin registration singleton
- `app/lib/plugins/builtin/` — All built-in plugins (reference implementations)
- `app/lib/widgets/renderers/custom/` — Custom renderer widgets
- `app/lib/theme/colors.dart` — LoggerColors (Ayu Dark inspired)
- `app/lib/theme/typography.dart` — LoggerTypography (JetBrains Mono + Inter)
- `app/lib/theme/constants.dart` — Spacing, border radii
- `app/lib/models/log_entry.dart` — LogEntry model
- `app/lib/models/data_state_models.dart` — WidgetPayload Dart model
- `packages/demo/src/scenarios/` — Demo scenario scripts

### Plugin Interface

```dart
// RendererPlugin — extend this for your widget
abstract class RendererPlugin extends LoggerPlugin {
  Set<String> get customTypes;  // e.g. {'[WIDGET_TYPE]'}
  Widget buildRenderer(BuildContext context, Map<String, dynamic> data, LogEntry entry);
  Widget? buildPreview(Map<String, dynamic> data) => null;  // compact single-line preview
}

// FilterPlugin — optional, for widget-specific filtering
abstract class FilterPlugin extends LoggerPlugin {
  String get filterLabel;
  IconData get filterIcon;
  bool matches(LogEntry entry, String query);
  List<String> getSuggestions(String partialQuery, List<LogEntry> entries);
}

// Plugin registration (in main.dart)
PluginRegistry.instance.register(MyRendererPlugin());
PluginRegistry.instance.register(MyFilterPlugin());  // optional
```

### Theme Tokens (Non-Negotiable — Use These Exactly)

```dart
// Backgrounds
LoggerColors.bgBase       // #0B0E14 — app canvas
LoggerColors.bgSurface    // #0F1219 — default row bg
LoggerColors.bgRaised     // #141820 — elevated cards
LoggerColors.bgOverlay    // #1A1F2B — popover/modal bg
LoggerColors.bgHover      // #1E2433 — hover state
LoggerColors.bgActive     // #252C3A — active/selected state

// Text
LoggerColors.fgPrimary    // #D4CCBA — main content text
LoggerColors.fgSecondary  // #8A8473 — secondary/meta text
LoggerColors.fgMuted      // #565165 — deemphasized text, chevrons, separators

// Borders
LoggerColors.borderSubtle // #1C2130 — section dividers, left-border accents
LoggerColors.borderDefault// #2A3040 — visible borders
LoggerColors.borderFocus  // #E6B455 — keyboard focus ring, update flash

// Severity (use for status signaling)
LoggerColors.severityInfoText    // #7EB8D0 — success / info
LoggerColors.severityWarningText // #E6B455 — warning / attention
LoggerColors.severityErrorText   // #F07668 — error / danger
LoggerColors.severityCriticalText// #F4708B — critical

// Syntax (use for structured data coloring)
syntaxKey       // #7EB8D0 — keys, labels
syntaxString    // #A8CC7E — success alt, string values
syntaxNumber    // #E6B455 — numeric values, durations, sizes
syntaxUrl       // #6EB5A6 — URLs, links
syntaxError     // #F07668 — error text
syntaxPunctuation // #565165 — separators

// Typography
LoggerTypography.logBody   // JetBrains Mono, 12dp, w400, h1.35, fgPrimary (main content)
LoggerTypography.logMeta   // JetBrains Mono, 10dp, w400, h1.20, fgSecondary (metadata)
LoggerTypography.sectionH  // Inter, 11dp, w700, h1.30, fgPrimary (section headings)
LoggerTypography.badge     // Inter, 9dp, w700, h1.30, fgPrimary (compact labels)

// Spacing constants
kBorderRadius    // 4px — standard radius
kBorderRadiusSm  // 3px — compact elements
kBorderRadiusLg  // 6px — cards
kHPadding8       // EdgeInsets.symmetric(horizontal: 8)
```

### Widget: [WIDGET_NAME]

**Type string:** `[WIDGET_TYPE]` (used in `widget.type` field in wire protocol)

**Description:** [DESCRIPTION — what this widget visualizes, what problem it solves]

**Target user:** [WHO uses this — e.g., "backend devs debugging X", "frontend devs monitoring Y"]

### Requirements

Every widget MUST deliver:

- [ ] **Zod schema** in `packages/shared/src/widget.ts` — add to `WidgetPayload` discriminated union
- [ ] **Client builder function** in `packages/client/src/logger-builders.ts` — `build[Name]Entry()`
- [ ] **Client SDK method** in `packages/client/src/logger.ts` — `Logger.[name]()`
- [ ] **RendererPlugin** in `app/lib/plugins/builtin/[name]_plugin.dart`
- [ ] **Renderer widget(s)** in `app/lib/widgets/renderers/custom/[name]/` (decompose into sub-widgets)
- [ ] **Plugin registration** in `app/lib/main.dart`
- [ ] **`buildPreview()`** returning a compact single-line `Text.rich` widget
- [ ] **Demo scenarios** in `packages/demo/src/scenarios/[name].ts` (5-10 scenarios)
- [ ] **Tests**: plugin identity, renderer widgets, utility functions (target 50+ tests)

Optional but recommended:
- [ ] **FilterPlugin** if the widget type has filterable attributes
- [ ] **Utility file** `[name]_utils.dart` for shared helpers (formatting, classification)

### Quality Criteria (Learned from HTTP Widget)

1. **Sub-widget decomposition** — Split the renderer into focused sub-widgets (<150 lines each). The HTTP widget split into: collapsed_row, timing_bar, headers_section, body_section, meta_section, url_section, utils. This keeps each file testable and readable.

2. **Information hierarchy** — Design 3-4 levels:
   - L0: `buildPreview()` — single-line Text.rich, used in tooltips and stacking
   - L1: Collapsed row — always visible in the log list, ~28dp height
   - L2: Conditional hint — extra info shown without full expansion (e.g., error excerpt)
   - L3: Full expanded view — all details in sections

3. **Expand/collapse with AnimatedSize** — Wrap expanded content in `AnimatedSize(duration: Duration(milliseconds: 150), curve: Curves.easeOutCubic)`. Respect `MediaQuery.disableAnimations` → `Duration.zero`.

4. **Left-border sections** — Expanded sections use a 2px `borderSubtle` left-border with 16dp indent. Section titles in `fgMuted`. No heavy Container backgrounds.

5. **Conflict-free design** — Resolve information density vs. cleanness by:
   - Collapsed: 4-5 essential fields only
   - Expanded: full detail in collapsible sections
   - Conditional rows: show extra info for anomalies without full expand

6. **Color coding for severity signal** — Use severity tokens for status indication. Normal states recede (`fgSecondary`), anomalies pop (`severityWarningText` or `severityErrorText`).

7. **All schema fields rendered** — Don't leave fields unused. Every field in the Zod schema should appear somewhere in the renderer (at least in expanded/meta section).

8. **Stacking support** — If the widget supports lifecycle updates (e.g., pending→complete), use `{ id: stableId, replace: true }` in the client builder. Design for field-level update highlighting (400ms `borderFocus` flash at 0.15 alpha).

### House Style Constraints (Non-Negotiable)

- **File size**: Target 150 lines, hard max 300 lines per file. Split aggressively.
- **Fonts**: JetBrains Mono for log content, Inter for UI chrome. Never mix.
- **Colors**: ONLY use `LoggerColors.*` tokens. Never hardcode hex values (except where a token doesn't exist — document it as tech debt).
- **Null tinting**: No colored backgrounds for normal entries. Only error/warning tinting.
- **Dart style**: Follow `analysis_options.yaml`. No `dynamic` casts when types are known. Use `(data['field'] as num?)?.toInt()` for safe numeric extraction.
- **Plugin ID**: Reverse-domain format: `dev.logger.[plugin-name]`
- **`buildPreview()` format**: `[KEY_FIELD] summary → STATUS` as `Text.rich` with `logMeta` style
- **Widget data access**: `widget.entry.widget?.data` — data is `Map<String, dynamic>`, never null for valid entries
- **Testing**: Colocated tests in `app/test/` mirroring `app/lib/` structure

### Schema

Define the Zod schema in `packages/shared/src/widget.ts`:

```typescript
const [WidgetName]Widget = z.object({
  type: z.literal('[WIDGET_TYPE]'),
  // [FIELD_NAME]: z.[TYPE].[MODIFIERS]  // [PURPOSE]
  // ...
}).passthrough()

// Add to WidgetPayload union:
export const WidgetPayload = z.discriminatedUnion('type', [
  // ... existing entries ...
  [WidgetName]Widget,
])
```

Ensure all non-required fields use `.optional()`. Use `.passthrough()` for forward compatibility.

### Demo Scenarios

Create `packages/demo/src/scenarios/[name].ts`:

```typescript
import { Logger } from '@logger/client'
const delay = (ms: number) => new Promise(r => setTimeout(r, ms))

export async function run[WidgetName]() {
  const logger = new Logger({ app: 'demo-[name]', transport: 'http' })
  try {
    // Scenario 1: [HAPPY_PATH — normal usage]
    // Scenario 2: [VARIATION — different parameters]
    // Scenario 3: [ERROR_STATE — what failure looks like]
    // Scenario 4: [EDGE_CASE — extreme values, missing fields]
    // Scenario 5: [LIFECYCLE — if applicable, pending→complete via replace:true]
    // ...add 400ms delay() between scenarios for visual pacing
    await logger.flush()
  } finally { await logger.close() }
}
```

Register in `packages/demo/src/main.ts`.

### Test Patterns

Write tests in `app/test/plugins/builtin/[name]_widget_test.dart`:

```dart
// Group 1: Plugin identity (id, name, version, customTypes, manifest)
// Group 2: buildPreview (returns widget for valid data, null for invalid)
// Group 3: buildRenderer (returns correct widget type)
// Group 4: Renderer sub-widgets (each sub-widget renders expected elements)
// Group 5: Utility functions (each helper tested with edge cases)
// Group 6: FilterPlugin (if exists — matches() for each query type, suggestions)
```

Use `testWidgets` for widget rendering. Use `MaterialApp` wrapper. Create `LogEntry` fixtures with the widget type's data. Test null/missing fields — renderers must handle graceful degradation.

---

## Success Factors (Extracted from HTTP Widget Development)

1. **Zero-TBD design spec**: Every conflict was resolved in the design phase. The implementer never had to make architectural decisions. 13 conflicts were documented with stakeholder perspectives and resolved with explicit trade-offs.

2. **Sub-widget decomposition upfront**: Deciding the file decomposition before implementation prevented monolithic files and enabled parallel wave implementation.

3. **Wave-based implementation**: 4 waves (utils+sub-widgets → body+collapsed+rewrite → filters+URL → tests+demo) allowed incremental verification. Each wave committed cleanly.

4. **Existing schema sufficiency check**: The HTTP widget needed zero wire protocol changes — all fields already existed in the Zod schema. Checking this early prevented wasted effort.

5. **Strict theme token discipline**: Using only `LoggerColors.*` and `LoggerTypography.*` tokens ensured visual consistency. The single exception (raw `Color(0x15E06C60)` for error hint bg) was documented as tech debt.

6. **`buildPreview()` from day one**: Implementing the compact preview enables the log list to show dense summaries without expansion, and feeds into stacking UI.

7. **Conflict resolution as a design artifact**: Documenting 13 conflicts with named personas, both sides, and resolution rationale created a reusable decision log. Future widgets can reference the same trade-offs.

## Common Pitfalls (Learned the Hard Way)

1. **Magic numbers for layout offsets**: The stack badge overlap fix used `40dp` as a magic number. Extract constants or compute from widget geometry instead.

2. **Missing tokens → raw Color literals**: When `LoggerColors` lacks a needed token (e.g., `severityErrorBg`), the implementer hardcodes hex. Instead: propose the token addition as a first step, or document it as priority tech debt.

3. **Client builder type gaps**: The `buildHttpEntry()` TypeScript function's type signature didn't include all fields from the Zod schema (e.g., `status_text`, `ttfb_ms`, `request_body_size`, `response_body_size` are in the schema but missing from the builder's typed options). This means the demo has to rely on auto-inference or the fields go unused. **Audit the builder type against the Zod schema before implementing.**

4. **Timeout detection gap**: The HTTP widget design says timeout is `is_error && !status`, but the client builder only sets `is_error` when `status >= 400`. A timeout (no response = no status) means `is_error` is never set automatically. This creates a detection gap. **Ensure lifecycle states are explicitly representable via the builder API.**

5. **progress.md drift**: The progress tracker wasn't updated after each wave. This makes it harder for the next SA to know the actual state. Keep progress files current.

6. **Expanded section overflow**: Large bodies (2MB+ JSON) can cause layout jank. Always use `maxHeight` constraints on scrollable body containers and test with pathologically large data.

7. **Missing accessibility annotations**: Screen reader labels and focus traversal are specified in the design but easy to forget during implementation. Include `Semantics()` wrappers and `Focus` widgets from the first wave.

8. **Filter plugin edge cases**: Substring matching on URLs (`http:url~pattern`) is case-sensitive by default. Decide early whether filters are case-insensitive and be consistent.
