#!/usr/bin/env bun
/**
 * capture-docs-screenshots.ts
 *
 * Captures documentation screenshots of the Logger Flutter app.
 *
 * Prerequisites:
 *   - Flutter app built for linux: cd app && flutter build linux
 *   - A running X11/Wayland display (or Xvfb for headless)
 *   - ImageMagick (`import` command) installed
 *   - Docker Compose available (for server + demo)
 *   - xdotool installed (for window management)
 *
 * Usage:
 *   bun run scripts/capture-docs-screenshots.ts
 *   bun run scripts/capture-docs-screenshots.ts --headless   # uses Xvfb
 */

import { $, sleep } from "bun";
import { existsSync, mkdirSync } from "fs";
import { join, resolve } from "path";

// ─── Configuration ───────────────────────────────────────────────────

const ROOT = resolve(import.meta.dir, "..");
const APP_BUNDLE = join(ROOT, "app/build/linux/x64/release/bundle/app");
const SCREENSHOT_DIR = join(ROOT, "docs/screenshots");
const COMPOSE_FILE = join(ROOT, "compose.yml");

/** Delay (ms) after launching the app before first screenshot */
const APP_STARTUP_DELAY = 4_000;

/** Delay (ms) after docker compose up before launching the app */
const SERVER_STARTUP_DELAY = 8_000;

/** Delay (ms) waiting for log entries to populate after demo starts */
const LOG_POPULATE_DELAY = 6_000;

/** Delay (ms) between individual screenshots */
const SCREENSHOT_INTERVAL = 1_500;

/** App window title to search for via xdotool */
const WINDOW_TITLE = "Logger";

const HEADLESS = process.argv.includes("--headless");

// ─── Types ───────────────────────────────────────────────────────────

interface Screenshot {
  name: string;
  description: string;
  /** Optional setup commands to run before capture */
  setup?: () => Promise<void>;
}

// ─── Helpers ─────────────────────────────────────────────────────────

function log(msg: string) {
  console.log(`[screenshot] ${msg}`);
}

function fatal(msg: string): never {
  console.error(`[screenshot] FATAL: ${msg}`);
  process.exit(1);
}

async function commandExists(cmd: string): Promise<boolean> {
  try {
    await $`which ${cmd}`.quiet();
    return true;
  } catch {
    return false;
  }
}

async function getWindowId(): Promise<string | null> {
  try {
    const result = await $`xdotool search --name ${WINDOW_TITLE}`.text();
    const ids = result.trim().split("\n").filter(Boolean);
    return ids[0] ?? null;
  } catch {
    return null;
  }
}

async function focusWindow(windowId: string) {
  await $`xdotool windowactivate --sync ${windowId}`.quiet();
  await sleep(300);
}

async function captureWindow(windowId: string, filename: string) {
  const outPath = join(SCREENSHOT_DIR, filename);
  // Use ImageMagick import to capture the specific window
  await $`import -window ${windowId} ${outPath}`.quiet();
  log(`  Saved: ${filename}`);
}

async function captureFullScreen(filename: string) {
  const outPath = join(SCREENSHOT_DIR, filename);
  await $`import -window root ${outPath}`.quiet();
  log(`  Saved (fullscreen): ${filename}`);
}

// ─── Prerequisite Checks ─────────────────────────────────────────────

async function checkPrerequisites() {
  log("Checking prerequisites...");

  if (!existsSync(APP_BUNDLE)) {
    fatal(
      `Flutter app not built. Run: cd ${ROOT}/app && flutter build linux`
    );
  }

  for (const cmd of ["import", "xdotool", "docker"]) {
    if (!(await commandExists(cmd))) {
      fatal(`Required command '${cmd}' not found. Please install it.`);
    }
  }

  if (HEADLESS && !(await commandExists("Xvfb"))) {
    fatal("Headless mode requires Xvfb. Install: apt install xvfb");
  }

  if (!HEADLESS && !process.env.DISPLAY && !process.env.WAYLAND_DISPLAY) {
    fatal("No display detected. Use --headless or set DISPLAY.");
  }

  log("Prerequisites OK.");
}

// ─── Process Management ──────────────────────────────────────────────

let xvfbProc: ReturnType<typeof Bun.spawn> | null = null;
let appProc: ReturnType<typeof Bun.spawn> | null = null;
let composeUp = false;

async function startXvfb(): Promise<string> {
  const display = ":99";
  log(`Starting Xvfb on ${display}...`);
  xvfbProc = Bun.spawn(["Xvfb", display, "-screen", "0", "1920x1080x24"], {
    stdout: "ignore",
    stderr: "ignore",
  });
  await sleep(1_000);
  return display;
}

async function startServices() {
  log("Starting server + demo via docker compose...");
  await $`docker compose -f ${COMPOSE_FILE} up -d server demo`.quiet();
  composeUp = true;
  log(`Waiting ${SERVER_STARTUP_DELAY / 1000}s for services to be ready...`);
  await sleep(SERVER_STARTUP_DELAY);
}

async function startApp(env: Record<string, string> = {}) {
  log("Launching Flutter app...");
  appProc = Bun.spawn([APP_BUNDLE], {
    env: { ...process.env, ...env },
    stdout: "ignore",
    stderr: "ignore",
  });
  log(`Waiting ${APP_STARTUP_DELAY / 1000}s for app to start...`);
  await sleep(APP_STARTUP_DELAY);
}

async function cleanup() {
  log("Cleaning up...");

  if (appProc) {
    try {
      appProc.kill();
      log("  Stopped Flutter app.");
    } catch {}
  }

  if (composeUp) {
    try {
      await $`docker compose -f ${COMPOSE_FILE} down`.quiet();
      log("  Stopped docker compose services.");
    } catch {}
  }

  if (xvfbProc) {
    try {
      xvfbProc.kill();
      log("  Stopped Xvfb.");
    } catch {}
  }
}

// ─── Screenshot Definitions ──────────────────────────────────────────

const screenshots: Screenshot[] = [
  {
    name: "01-app-overview.png",
    description: "Full app overview with log entries visible",
  },
  {
    name: "02-custom-renderers.png",
    description: "Custom renderers: progress bars, tables, key-value pairs",
  },
  {
    name: "03-error-stack-trace.png",
    description: "Error log entry with expanded stack trace",
  },
  {
    name: "04-session-selection.png",
    description: "Session selection sidebar",
  },
  {
    name: "05-filter-bar.png",
    description: "Active filter bar with severity and text filters",
  },
  {
    name: "06-sticky-grouping.png",
    description: "Sticky session/source grouping headers",
  },
];

// ─── Main ────────────────────────────────────────────────────────────

async function main() {
  await checkPrerequisites();

  // Ensure output directory exists
  mkdirSync(SCREENSHOT_DIR, { recursive: true });

  // Set up display
  let displayEnv: Record<string, string> = {};
  if (HEADLESS) {
    const display = await startXvfb();
    displayEnv = { DISPLAY: display, GDK_BACKEND: "x11" };
    process.env.DISPLAY = display;
  }

  try {
    // Start backend services
    await startServices();

    // Launch the Flutter app
    await startApp(displayEnv);

    // Wait for logs to populate from demo service
    log(
      `Waiting ${LOG_POPULATE_DELAY / 1000}s for log entries to populate...`
    );
    await sleep(LOG_POPULATE_DELAY);

    // Find the app window
    const windowId = await getWindowId();
    if (!windowId) {
      fatal(
        "Could not find app window. Is the app running with a visible display?"
      );
    }
    log(`Found window: ${windowId}`);

    // Capture each screenshot
    for (const shot of screenshots) {
      log(`Capturing: ${shot.description}...`);
      await focusWindow(windowId);

      if (shot.setup) {
        await shot.setup();
        await sleep(500);
      }

      await captureWindow(windowId, shot.name);
      await sleep(SCREENSHOT_INTERVAL);
    }

    log(`\nDone! ${screenshots.length} screenshots saved to ${SCREENSHOT_DIR}`);
  } finally {
    await cleanup();
  }
}

main().catch((err) => {
  console.error(err);
  cleanup().finally(() => process.exit(1));
});
