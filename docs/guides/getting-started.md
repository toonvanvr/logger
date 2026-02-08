# Getting Started

This guide walks through setting up the Logger system from scratch.

## Prerequisites

- **Docker** and **Docker Compose** — runs the server, Loki, and Grafana
- **Flutter** 3.10+ — builds the desktop viewer
- **Bun** 1.0+ — runs TypeScript components and scripts

## Step 1: Clone and Install

```bash
git clone <repo-url> logger
cd logger
```

No top-level install step is needed — each component manages its own dependencies.

## Step 2: Start the Backend

```bash
docker compose up -d
```

Wait for all services to report healthy:

```bash
docker compose ps
```

You should see `loki`, `grafana`, `server`, and `demo` all running.

## Step 3: Build the Viewer

```bash
cd app
flutter pub get
flutter build linux
```

## Step 4: Launch

```bash
./build/linux/x64/release/bundle/app
```

The viewer will connect to the server at `ws://localhost:8082` and begin displaying log entries from the demo service.

## Step 5: Explore

- **Grafana**: http://localhost:3000 (admin/admin)
- **Server health**: http://localhost:8080/health
- **Viewer**: The Flutter desktop app

## Next Steps

- Read the [Features Guide](features.md) for an overview of viewer capabilities
- Integrate the client SDK into your own application (see [main README](../README.md#3-integrate-your-application))
