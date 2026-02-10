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

### Build and Run the Viewer

```bash
cd app && flutter pub get && flutter run -d linux
```

The viewer auto-connects to `ws://localhost:8080`. You'll see server logs in the console — Loki connection warnings are expected and can be ignored.

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

```bash
cd app
flutter pub get
flutter build linux
./build/linux/x64/release/bundle/app
```

The viewer connects to `ws://localhost:8080` and begins displaying log entries from the demo service.

### Explore

- **Grafana**: http://localhost:3000 (admin/admin)
- **Server health**: http://localhost:8080/health
- **Viewer**: The Flutter desktop app

## Next Steps

- Read the [Features Guide](features.md) for an overview of viewer capabilities
- Integrate the client SDK into your own application (see [main README](../README.md#client-sdk))
