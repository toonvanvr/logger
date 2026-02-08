# Skill: Flutter Linux Build & Test

## Prerequisites

- **mise** for tool version management (manages Flutter SDK, Dart, clang)
- **clang** installed via mise (e.g., `clang/21.1.8`)
- **Linux desktop** development dependencies: `libgtk-3-dev`, `libblkid-dev`, etc.

## Known Issue: mise clang missing linker/archiver

Flutter's native build expects `ld` and `ar` in the same directory as `clang++`. mise's clang install doesn't include them.

### Fix

```bash
CLANG_BIN=$(dirname "$(which clang++)")
ln -sf /usr/bin/ld "$CLANG_BIN/ld"
ln -sf /usr/bin/ar "$CLANG_BIN/ar"
```

Re-run after `mise install clang` upgrades.

## Build Commands

```bash
# Development
cd app && flutter run -d linux

# Release build
cd app && flutter build linux

# Run release binary
./app/build/linux/x64/release/bundle/app
```

## Test Commands

```bash
# All Flutter tests
cd app && flutter test

# Specific test file
cd app && flutter test test/services/query_store_test.dart

# Static analysis
cd app && flutter analyze

# Full stack (all packages)
cd server && bun test
cd client && bun test
cd shared && bun test
cd mcp && bun test
cd app && flutter test
```

## Docker

```bash
docker compose up -d          # Loki + Grafana + Server + Demo
docker compose logs server    # Check server logs
```

## Display Issues

- For headless/CI: use `xvfb-run flutter test` or set `DISPLAY=:99`
- GTK warnings (`Atk-CRITICAL`, `Gdk-CRITICAL`) are cosmetic — not blockers
- Connection refused on port 34140 at startup is expected when server isn't running

## Integration Tests

```bash
cd app && flutter test integration_test/ -d linux
```

Requires a running display server (X11 or Wayland).
