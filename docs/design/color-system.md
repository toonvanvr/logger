# Color System Reference

Logger's color system is inspired by Ayu Dark's warmth and low-saturation philosophy. All colors are designed for extended dark-mode use with WCAG AA+ contrast where text is involved.

Full definitions live in `app/lib/theme/` (Dart) and in the UX design spec (`.ai/memory/design-ux.md`).

## Background Layers

Backgrounds form a depth hierarchy from deepest to most prominent:

| Token | Hex | Usage |
|-------|-----|-------|
| `bg.base` | `#0B0E14` | Window background, deepest layer |
| `bg.surface` | `#0F1219` | Log list background, main content area |
| `bg.raised` | `#141820` | Header bar, section headers, cards |
| `bg.overlay` | `#1A1F2B` | Dropdowns, tooltips, floating panels |
| `bg.hover` | `#1E2433` | Hovered log line, hovered button |
| `bg.active` | `#252C3A` | Active/selected log line, pressed button |
| `bg.divider` | `#1C2130` | Section dividers, subtle borders |

## Foreground / Text

| Token | Hex | Usage |
|-------|-----|-------|
| `fg.primary` | `#D4CCBA` | Primary log text, headings |
| `fg.secondary` | `#8A8473` | Timestamps, metadata, labels |
| `fg.muted` | `#565165` | Disabled text, placeholders, line numbers |
| `fg.inverse` | `#0B0E14` | Text on bright backgrounds (badges) |

## Borders

| Token | Hex | Usage |
|-------|-----|-------|
| `border.subtle` | `#1C2130` | Dividers between log lines (1px) |
| `border.default` | `#2A3040` | Input borders, panel edges |
| `border.focus` | `#E6B455` | Focus rings, active input |

## Severity Colors

Each severity has three variants: bar (full saturation), background tint (low opacity), and text (readable on dark).

| Severity | Bar | Background Tint | Text |
|----------|-----|-----------------|------|
| Debug | `#636D83` | `#636D8310` | `#636D83` |
| Info | `#7EB8D0` | `#7EB8D010` | `#7EB8D0` |
| Warning | `#E6B455` | `#E6B45512` | `#E6B455` |
| Error | `#E06C60` | `#E06C6015` | `#F07668` |
| Critical | `#D94F68` | `#D94F6820` | `#F4708B` |

## Session / App Colors

12 colors that cycle for multi-app sessions, chosen for distinguishability on dark backgrounds:

| Index | Hex | Name |
|-------|-----|------|
| 0 | `#7EB8D0` | pool-cyan |
| 1 | `#E6B455` | pool-amber |
| 2 | `#A8CC7E` | pool-green |
| 3 | `#D99AE6` | pool-lavender |
| 4 | `#F07668` | pool-salmon |
| 5 | `#6EB5A6` | pool-teal |
| 6 | `#D4A07A` | pool-peach |
| 7 | `#8DA4EF` | pool-periwinkle |
| 8 | `#E68ABD` | pool-rose |
| 9 | `#B8CC52` | pool-lime |
| 10 | `#CC8C7A` | pool-clay |
| 11 | `#7ACCE6` | pool-sky |

Assignment: Round-robin by order of first log received from each application. Persistent within a viewer session.

## Syntax Highlighting

Used for structured content rendering in log entries:

| Token | Hex | Usage |
|-------|-----|-------|
| `syntax.string` | `#A8CC7E` | Quoted strings |
| `syntax.number` | `#E6B455` | Numeric values |
| `syntax.boolean` | `#F07668` | `true` / `false` |
| `syntax.null` | `#636D83` | `null`, `undefined` |
| `syntax.key` | `#7EB8D0` | JSON keys, property names |
| `syntax.date` | `#D99AE6` | ISO 8601 dates |
| `syntax.url` | `#6EB5A6` | URLs (underlined) |
| `syntax.punctuation` | `#565165` | Braces, brackets, commas |
| `syntax.error` | `#F07668` | Error type names |
| `syntax.path` | `#8DA4EF` | File paths in stack traces |
| `syntax.lineNumber` | `#636D83` | Line:column references |
