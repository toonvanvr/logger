# .ai/library Index

Knowledge persistence layer for the Logger project.

## Patterns
- [patterns/flutter.md](patterns/flutter.md) —
  Flutter layout, architecture, chart system
- [patterns/typescript.md](patterns/typescript.md) —
  Client SDK, server, MCP patterns
- [patterns/plugin-registry.md](patterns/plugin-registry.md) —
  Singleton plugin registry with typed resolution
- [desktop-plugin-arch](patterns/flutter-desktop-plugin-architecture.md)
  — AOT-compatible tiered plugin architecture
- [patterns/file-mediated-state.md](patterns/file-mediated-state.md) —
  State transfer between sub-agents via files

## Domain
- [domain/log-protocol.md](domain/log-protocol.md) —
  State keys, severity, log types, sections
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
