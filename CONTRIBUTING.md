# Contributing to Logger

## Quick Start

**Prerequisites:** Bun v1.3+, Flutter 3.x stable, Docker (optional). Linux and macOS are supported platforms.

## Development Setup

```bash
git clone https://github.com/<your-fork>/logger.git
cd logger
cd packages/shared && bun install && cd ../..
cd packages/client && bun install && cd ../..
cd packages/server && bun install && cd ../..
cd app && flutter pub get && cd ..
```

## Running Tests

```bash
cd packages/shared && bun test
cd packages/client && bun test
cd packages/server && bun test
cd app && flutter test
```

All tests must pass before submitting a PR.

## Running Locally

```bash
cd packages/server && bun run src/main.ts   # Start log server on :8080
cd app && flutter run -d linux               # Launch the viewer app (Linux)
cd app && flutter run -d macos               # Launch the viewer app (macOS)
```

Or use Docker Compose for the full stack: `docker compose up -d`

## Code Style

- **File size:** target 150 lines, hard max 300 lines per file.
- **Dart:** use `dart format`. Provider for state management. JetBrains Mono + Inter fonts.
- **TypeScript:** Zod schemas live in `packages/shared/` as the single source of truth.
- **Tests:** colocated (`foo.test.ts` next to `foo.ts`), or `test/` mirroring `lib/` in Flutter.

## License

This project is licensed under **MPL-2.0**. Contributions to existing files fall under the same license. New plugin files may use any MPL-2.0-compatible license.

## PR Process

1. Fork the repo and create a feature branch.
2. Make your changes — keep commits focused.
3. Ensure all tests pass (`bun test` / `flutter test`).
4. Submit a pull request with a clear description of the change.

## Vibe Coding (AI-Assisted Development)

When using AI agents for development:

- **Branch:** use `vibe/` prefix (e.g., `vibe/feature-name`)
- **Commits:** use `vibe(subject): description` format
- **Workflow:** agents commit on `vibe/` branches, humans review and merge to `main`
- **CI** runs on all branches; releases only from `main`
