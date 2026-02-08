# Flutter Linux Build — mise/clang Environment Fix

## Problem

When `mise` installs clang (e.g. `clang/21.1.8`), it places only the compiler binaries (`clang`, `clang++`, `clang-cl`, `clang-cpp`) in its bin directory. Flutter's Dart native build toolchain expects the linker (`ld` or `ld.lld`) and archiver (`ar` or `llvm-ar`) to be co-located with the compiler.

**Error sequence:**
1. `Failed to find any of [ld.lld, ld] in LocalDirectory: '.../mise/installs/clang/21.1.8/bin'`
2. `Failed to find any of [llvm-ar, ar] in LocalDirectory: '.../mise/installs/clang/21.1.8/bin'`

## Root Cause

Flutter's native asset build resolves `clang++` from PATH, determines its parent directory, then looks for the linker and archiver in that same directory. mise's clang install doesn't include those tools.

## Fix

Symlink the system linker and archiver into mise's clang bin directory:

```bash
CLANG_BIN=$(dirname "$(which clang++)")
ln -sf /usr/bin/ld "$CLANG_BIN/ld"
ln -sf /usr/bin/ar "$CLANG_BIN/ar"
```

## Verification

```bash
cd app && flutter run -d linux
```

Should output `✓ Built build/linux/x64/debug/bundle/app` and launch the app.

## Notes

- The WebSocket connection error (`Connection refused, errno = 111, port 34140`) on launch is expected when the logger server is not running.
- The `Atk-CRITICAL` and `Gdk-CRITICAL` warnings are cosmetic GTK issues, not blockers.
- This fix survives until mise reinstalls/upgrades clang. Re-run the symlink commands after `mise install clang`.
