# Skill: Modularity Refactoring

## Project Convention

- **Target**: 150 lines per file
- **Hard max**: 300 lines per file
- **Tests**: Colocated alongside implementation (e.g., `foo.test.ts` next to `foo.ts` in TS; `test/` mirrors `lib/` in Flutter)

## When to Split

1. File exceeds 150 lines
2. File has 2+ distinct responsibilities
3. A class/function could be independently tested
4. An import graph shows circular dependencies forming

## Patterns for Splitting

### Extract Widget (Flutter)
```
# Before: log_row.dart (280 lines)
# After:
#   log_row.dart (120 lines) — main row widget
#   log_row_metadata.dart (80 lines) — timestamp/session metadata strip
#   log_row_actions.dart (60 lines) — copy/pin/expand actions
```

### Extract Module (TypeScript)
```
# Before: loki-forwarder.ts (250 lines)
# After:
#   loki-forwarder.ts (120 lines) — main forwarder class
#   loki-batch.ts (80 lines) — batch formatting logic
#   loki-types.ts (40 lines) — type definitions
```

### Extract Service
When a class grows, split along these axes:
- **Data model** → separate file with types/interfaces
- **Business logic** → service class
- **UI rendering** → widget/component
- **Utilities** → helper functions

## Checklist

1. Identify the split boundary (responsibility boundary)
2. Create the new file with the extracted code
3. Update imports in the original file
4. Update imports in all consumers
5. Move relevant tests to new test file
6. Run `flutter analyze` / `bun test` to verify
7. Check line counts: both files should be under 150

## Anti-Patterns

- Splitting into files that are too small (< 30 lines) — creates unnecessary indirection
- Splitting mid-class — keep classes cohesive, split at class boundaries
- Creating "util" dumping grounds — name files precisely
- Forgetting to update test imports after splitting
