# .ai/library Index

Knowledge persistence layer for the Logger project.

## Patterns
- [patterns/api-boundary-split.md](patterns/api-boundary-split.md) —
  API-boundary split with unified internal model
- [patterns/entry-stacking.md](patterns/entry-stacking.md) —
  Entry stacking (version history) in LogStore
- [patterns/plugin-registry.md](patterns/plugin-registry.md) —
  Singleton plugin registry with typed resolution
- [patterns/flutter-desktop-plugin-architecture.md](patterns/flutter-desktop-plugin-architecture.md) —
  AOT-compatible tiered plugin architecture
- [patterns/file-mediated-state.md](patterns/file-mediated-state.md) —
  State transfer between sub-agents via files

## Domain
- [domain/flutter-env.md](domain/flutter-env.md) —
  Flutter Linux build environment (mise/clang)

## Quirks
- [quirks/flutter.md](quirks/flutter.md) —
  Flutter desktop + dart format gotchas
- [quirks/bun.md](quirks/bun.md) —
  Bun runtime behavior

## Usage

- Agents scan patterns/ and domain/ at startup
- New knowledge added during execution
- See `README.md` for maintenance guidance
