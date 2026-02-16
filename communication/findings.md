## 2026-02-12T03:43:04+01:00 | scope-fence
Wave03 scope set to dependency graph + runtime separability + Loki/Grafana fit + storage strategy + fast paths + architecture perf hotspots; excluded UI-level design changes. Evidence anchor: user dispatch in current session.

## 2026-02-12T03:43:04+01:00 | dependency
Store backend seam is centralized in `createStoreWriter/createStoreReader`, selecting memory vs loki by config; this is a hard dependency switch point. Evidence: packages/server/src/store/index.ts:22-40.

## 2026-02-12T03:43:04+01:00 | runtime-separability
Minimal run path is server+viewer without Docker, and docs explicitly state Loki warnings can be ignored in this mode. Evidence: docs/guides/getting-started.md:5-27.

## 2026-02-12T03:43:04+01:00 | seam-limitation
HTTP query route currently reads from ring buffer directly rather than `storeReader`, limiting backend-agnostic read behavior at runtime. Evidence: packages/server/src/transport/http.ts:50,253.
## 2026-02-12T00:00:00Z | scope
Wave 02 scope confirmed: DO=architecture surface map across app/client/server/shared/demo/docker-sidecar/mcp/docs/infra; DO NOT=implementation edits.

## 2026-02-12T00:00:00Z | contracts
Shared schemas define protocol spine (`StoredEntry`, `ServerBroadcast`, `ViewerCommand`) and server/app integrate directly with these message shapes (packages/shared/src/stored-entry.ts:13, packages/shared/src/server-broadcast.ts:31, packages/shared/src/viewer-command.ts:6).

## 2026-02-12T00:00:00Z | extensibility
Explicit extension seams are documented in-code for server modules, app plugins, and demo scenarios (`HOW TO ADD` guides in packages/server/src/main.ts:14, app/lib/main.dart:35, packages/demo/src/main.ts:16).

## 2026-02-12T00:00:00Z | flutter-run-diagnosis
`cd app && flutter run -v` fails during Linux native compile because `app/linux/CMakeLists.txt` enforces `-Werror` and `app/linux/runner/my_application.cc` calls deprecated `app_indicator_new`, which is treated as a hard error by clang. Evidence: app/linux/CMakeLists.txt:44, app/linux/runner/my_application.cc:417, terminal output showing `-Werror,-Wdeprecated-declarations`.
