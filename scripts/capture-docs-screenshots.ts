#!/usr/bin/env bun
/**
 * capture-docs-screenshots.ts
 *
 * Captures documentation screenshots of the Logger Flutter app.
 * Uses scrot for window capture and direct HTTP POST for log injection.
 *
 * Prerequisites:
 *   - Flutter app built for linux: cd app && flutter build linux
 *   - scrot + xdotool installed
 *   - Docker Compose available (for server)
 *
 * Usage:
 *   bun run scripts/capture-docs-screenshots.ts
 *   bun run scripts/capture-docs-screenshots.ts --headless
 *   bun run scripts/capture-docs-screenshots.ts --ci
 */

import { $, sleep } from 'bun';
import { existsSync, mkdirSync } from 'fs';
import { join, resolve } from 'path';
import { scenarios } from './screenshot-scenarios';

// ─── Configuration ───────────────────────────────────────────────────

const ROOT = resolve(import.meta.dir, '..');
const APP_BUNDLE = join(ROOT, 'app/build/linux/x64/release/bundle/app');
const SCREENSHOT_DIR = join(ROOT, 'docs/screenshots');
const COMPOSE_FILE = join(ROOT, 'compose.yml');
const SERVER_URL = 'http://localhost:8080';

/** Delay (ms) after launching the app before first screenshot */
const APP_STARTUP_DELAY = 4_000;

/** Delay (ms) after docker compose up before launching the app */
const SERVER_STARTUP_DELAY = 5_000;

/** Delay (ms) after posting entries for WebSocket broadcast + render */
const RENDER_DELAY = 800;

/** App window title to search for via xdotool */
const WINDOW_TITLE = 'Logger';

const HEADLESS = process.argv.includes('--headless') || process.argv.includes('--ci');
const HELP = process.argv.includes('--help') || process.argv.includes('-h');

// ─── Help ────────────────────────────────────────────────────────────

if (HELP) {
  console.log(`Usage: bun run scripts/capture-docs-screenshots.ts [flags]

Flags:
  --headless   Run with Xvfb (no display required)
  --ci         Alias for --headless
  -h, --help   Show this help

Requires: scrot, xdotool, docker compose, Flutter linux build`);
  process.exit(0);
}

// ─── Helpers ─────────────────────────────────────────────────────────

function log(msg: string) {
  console.log(`[screenshot] ${msg}`);
}

function fatal(msg: string): never {
  console.error(`[screenshot] FATAL: ${msg}`);
  process.exit(1);
}

async function cmdExists(cmd: string): Promise<boolean> {
  try {
    await $`which ${cmd}`.quiet();
    return true;
  } catch {
    return false;
  }
}

async function getWindowId(): Promise<string | null> {
  try {
    const r = await $`xdotool search --name ${WINDOW_TITLE}`.text();
    const ids = r.trim().split('\n').filter(Boolean);
    return ids[0] ?? null;
  } catch {
    return null;
  }
}

async function focusWindow(wid: string) {
  await $`xdotool windowactivate --sync ${wid}`.quiet();
  await sleep(300);
}

async function captureWindow(wid: string, filename: string) {
  const outPath = join(SCREENSHOT_DIR, filename);
  await $`scrot --window ${wid} -F ${outPath}`.quiet();
  log(`  Saved: ${filename}`);
}

// ─── Prerequisite Checks ─────────────────────────────────────────────

async function checkPrerequisites() {
  log('Checking prerequisites...');

  if (!existsSync(APP_BUNDLE)) {
    fatal(`Flutter app not built. Run: cd ${ROOT}/app && flutter build linux`);
  }

  for (const cmd of ['scrot', 'xdotool', 'docker']) {
    if (!(await cmdExists(cmd))) {
      fatal(`Required command '${cmd}' not found. Please install it.`);
    }
  }

  if (HEADLESS && !(await cmdExists('Xvfb'))) {
    fatal('Headless mode requires Xvfb. Install: apt install xvfb');
  }

  if (!HEADLESS && !process.env.DISPLAY && !process.env.WAYLAND_DISPLAY) {
    fatal('No display detected. Use --headless or set DISPLAY.');
  }

  log('Prerequisites OK.');
}

// ─── Process Management ──────────────────────────────────────────────

let xvfbProc: ReturnType<typeof Bun.spawn> | null = null;
let appProc: ReturnType<typeof Bun.spawn> | null = null;
let composeUp = false;

async function startXvfb(): Promise<string> {
  const display = ':99';
  log(`Starting Xvfb on ${display}...`);
  xvfbProc = Bun.spawn(['Xvfb', display, '-screen', '0', '1920x1080x24'], {
    stdout: 'ignore',
    stderr: 'ignore',
  });
  await sleep(1_000);
  return display;
}

async function startServer() {
  log('Starting server via docker compose...');
  await $`docker compose -f ${COMPOSE_FILE} up -d server`.quiet();
  composeUp = true;
  log(`Waiting ${SERVER_STARTUP_DELAY / 1000}s for server to be ready...`);
  await sleep(SERVER_STARTUP_DELAY);
}

async function startApp(env: Record<string, string> = {}) {
  log('Launching Flutter app...');
  appProc = Bun.spawn([APP_BUNDLE], {
    env: { ...process.env, ...env },
    stdout: 'ignore',
    stderr: 'ignore',
  });
  log(`Waiting ${APP_STARTUP_DELAY / 1000}s for app to start...`);
  await sleep(APP_STARTUP_DELAY);
}

async function cleanup() {
  log('Cleaning up...');

  if (appProc) {
    try {
      appProc.kill();
      log('  Stopped Flutter app.');
    } catch {}
  }

  if (composeUp) {
    try {
      await $`docker compose -f ${COMPOSE_FILE} down server`.quiet();
      log('  Stopped server.');
    } catch {}
  }

  if (xvfbProc) {
    try {
      xvfbProc.kill();
      log('  Stopped Xvfb.');
    } catch {}
  }
}

// ─── Main ────────────────────────────────────────────────────────────

async function main() {
  await checkPrerequisites();

  mkdirSync(SCREENSHOT_DIR, { recursive: true });

  let displayEnv: Record<string, string> = {};
  if (HEADLESS) {
    const display = await startXvfb();
    displayEnv = { DISPLAY: display, GDK_BACKEND: 'x11' };
    process.env.DISPLAY = display;
  }

  try {
    await startServer();
    await startApp(displayEnv);

    const windowId = await getWindowId();
    if (!windowId) {
      fatal('Could not find app window. Is the app running with a visible display?');
    }
    log(`Found window: ${windowId}`);

    for (const scenario of scenarios) {
      log(`Scenario: ${scenario.description}...`);
      await focusWindow(windowId);
      await scenario.setup(SERVER_URL);
      await sleep(RENDER_DELAY);
      await captureWindow(windowId, `${scenario.name}.png`);
    }

    log(`\nDone! ${scenarios.length} screenshots saved to ${SCREENSHOT_DIR}`);
  } finally {
    await cleanup();
  }
}

main().catch((err) => {
  console.error(err);
  cleanup().finally(() => process.exit(1));
});
