# AI Library

Per-repo knowledge persistence for the Logger project. Grows organically during agent sessions.

## Folders

- `skills/` — Teachable procedures (build, test, refactor patterns)
- `patterns/` — Reusable architectural solutions found in this codebase
- `research/` — Investigation findings and archived session research
- `domain/` — Business/technical domain concepts
- `quirks/` — Tool oddities and workarounds

## Key Patterns

| Pattern | File | Summary |
|---------|------|---------|
| Plugin Registry | `patterns/plugin-registry.md` | Singleton, typed resolution, manifest-driven |
| File-Mediated State | `patterns/file-mediated-state.md` | SA communication via filesystem |
| Flutter Desktop Plugin Arch | `patterns/flutter-desktop-plugin-architecture.md` | AOT-compatible tiered plugins |

## Key Skills

| Skill | File | Summary |
|-------|------|---------|
| Flutter Linux Build | `skills/flutter-linux-build.md` | mise env, clang symlinks, test commands |
| Modularity Refactor | `skills/modularity-refactor.md` | Keeping files ≤150 lines |

## Adding Knowledge

Agents add knowledge automatically during execution.
Manual additions welcome — use the appropriate folder.

## Maintenance

Run library maintenance skill periodically:
"Review the library and update outdated skills"
