# Getting Started

This guide walks through setting up the Logger system from scratch.

## Minimal Setup (No Docker)

The quickest way to try Logger — no Docker required.

### Prerequisites

- **Bun** 1.0+ — runs the server
- **Flutter** 3.10+ — builds the viewer

### Start the Server

```bash
cd packages/server && bun install && bun run src/main.ts
```

If startup fails with `EADDRINUSE`, another local process is already using one or more default bind ports (`8080`, `8081`, `8082`).

```bash
ss -ltnp | grep ':8080' || true
ss -lunp | grep ':8081' || true
ss -ltnp | grep ':8082' || true
cd packages/server && LOGGER_PORT=18080 LOGGER_UDP_PORT=18081 LOGGER_TCP_PORT=18082 bun run src/main.ts
```

When you use a non-default port, set the viewer connection base URL to `ws://127.0.0.1:18080/api/v2/stream`.

### Build and Run the Viewer

```bash
cd app && flutter pub get && flutter run -d linux   # Linux
cd app && flutter pub get && flutter run -d macos   # macOS
```

With default ports, the viewer auto-connects to `ws://localhost:8080`. You'll see server logs in the console — Loki connection warnings are expected and can be ignored.

### Send Test Logs

```bash
cd packages/demo && bun install && bun run src/main.ts
```

## Full Setup (Docker)

For Loki persistence and Grafana dashboards, use Docker Compose.

### Prerequisites

- **Docker** and **Docker Compose**
- **Flutter** 3.10+

### Clone and Install

```bash
git clone <repo-url> logger
cd logger
```

No top-level install step is needed — each component manages its own dependencies.

### Start the Backend

```bash
docker compose up -d
```

Wait for all services to report healthy:

```bash
docker compose ps
```

You should see `loki`, `grafana`, `server`, and `demo` all running.

### Build and Launch the Viewer

**Linux:**
```bash
cd app
flutter pub get
flutter build linux
./build/linux/x64/release/bundle/app
```

**macOS:**
```bash
cd app
flutter pub get
flutter build macos
open build/macos/Build/Products/Release/app.app
```

The viewer connects to `ws://localhost:8080` and begins displaying log entries from the demo service.

### Explore

- **Grafana**: http://localhost:3000 (admin/admin)
- **Server health**: http://localhost:8080/health
- **Viewer**: The Flutter desktop app

## Next Steps

- Read the [Features Guide](features.md) for an overview of viewer capabilities
- Integrate the client SDK into your own application (see [main README](../README.md#client-sdk))
