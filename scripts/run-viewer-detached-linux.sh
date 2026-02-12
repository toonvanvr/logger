#!/usr/bin/env bash
set -euo pipefail

# Run the Flutter desktop viewer detached from the current terminal (Linux).
#
# - Idempotent: if a PID file points to a live process, exits 0.
# - Ensures a release bundle exists; builds it if missing.
# - Detaches using nohup + setsid and redirects logs to an on-disk file.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$REPO_ROOT/app"
BINARY="$APP_DIR/build/linux/x64/release/bundle/app"

RUNTIME_DIR="${XDG_RUNTIME_DIR:-}"
CACHE_DIR="${XDG_CACHE_HOME:-${HOME:-}/.cache}"

if [[ -n "$RUNTIME_DIR" ]]; then
  STATE_DIR="$RUNTIME_DIR/logger"
else
  STATE_DIR="$CACHE_DIR/logger"
fi

PID_FILE="$STATE_DIR/viewer.pid"
LOG_FILE="$STATE_DIR/viewer.log"

mkdir -p "$STATE_DIR"

is_pid_alive() {
  local pid="$1"
  [[ -n "$pid" ]] || return 1
  [[ "$pid" =~ ^[0-9]+$ ]] || return 1
  kill -0 "$pid" 2>/dev/null
}

if [[ -f "$PID_FILE" ]]; then
  existing_pid="$(cat "$PID_FILE" 2>/dev/null || true)"
  if is_pid_alive "$existing_pid"; then
    echo "Viewer already running (pid=$existing_pid)"
    echo "Log: $LOG_FILE"
    exit 0
  fi
fi

if [[ ! -x "$BINARY" ]]; then
  if [[ -z "${DISPLAY:-}" && -z "${WAYLAND_DISPLAY:-}" ]]; then
    echo "No graphical session detected (DISPLAY/WAYLAND_DISPLAY not set)." >&2
    echo "The viewer requires an active desktop session to show a window/tray." >&2
  fi

  echo "Release binary not found; building Linux release..."
  pushd "$APP_DIR" >/dev/null
  flutter pub get
  flutter build linux --release
  popd >/dev/null
fi

if [[ ! -x "$BINARY" ]]; then
  echo "Build did not produce expected binary: $BINARY" >&2
  exit 1
fi

# Detach.
# - setsid starts a new session to avoid terminal hangups.
# - nohup prevents SIGHUP termination.
# - redirect stdio to log file so the command returns immediately.
nohup setsid "$BINARY" >>"$LOG_FILE" 2>&1 </dev/null &
new_pid=$!

echo "$new_pid" >"$PID_FILE"

echo "Viewer launched (pid=$new_pid)"
echo "PID file: $PID_FILE"
echo "Log: $LOG_FILE"
echo "Quit via tray menu (Quit) or kill: kill $new_pid"
