#!/usr/bin/env bun
/** Deterministic log payloads for documentation screenshots. */

// ─── Helpers ─────────────────────────────────────────────────────────

const DEFAULT_SESSION = 'screenshot-demo';
const DEFAULT_APP = { name: 'Demo App', version: '2.4.1' };

let _id = 0;
let _ts = new Date('2026-01-15T10:00:00.000Z').getTime();

function nextId(): string {
  return `ss-${String(++_id).padStart(4, '0')}`;
}

function nextTs(): string {
  _ts += 1500;
  return new Date(_ts).toISOString();
}

type E = Record<string, unknown>;

function entry(o: E = {}): E {
  return {
    id: nextId(),
    timestamp: nextTs(),
    session_id: (o.session_id as string) ?? DEFAULT_SESSION,
    severity: 'info',
    type: 'text',
    application: DEFAULT_APP,
    ...o,
  };
}

export async function postEntries(url: string, entries: E[]) {
  const r = await fetch(`${url}/api/v1/logs`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ entries }),
  });
  if (!r.ok) {
    throw new Error(`POST /api/v1/logs failed: ${r.status} ${await r.text()}`);
  }
}

// ─── Scenario 1: App Overview ────────────────────────────────────────

export async function setupOverview(url: string) {
  await postEntries(url, [
    entry({ severity: 'info', text: 'Server started on port 8080', icon: { icon: 'mdi:server' } }),
    entry({ severity: 'debug', text: 'Database connection pool initialized (5 connections)' }),
    entry({ severity: 'info', text: 'Loading configuration from environment', section: 'config' }),
    entry({ severity: 'info', text: 'Connected: postgres://db.prod:5432/app' }),
    entry({ severity: 'info', text: 'Connected: redis://cache.prod:6379' }),
    entry({ severity: 'warning', text: 'Cache miss ratio is 45% — consider increasing cache size' }),
    entry({ type: 'group', group_id: 'g-deploy', group_action: 'open', group_label: 'Deploy Pipeline v2.4.1' }),
    entry({ text: 'Compiling TypeScript...', group_id: 'g-deploy' }),
    entry({ text: 'Bundle size: 2.4 MB (gzipped: 680 KB)', group_id: 'g-deploy' }),
    entry({ text: 'Running 342 unit tests... all passed ✓', group_id: 'g-deploy' }),
    entry({ text: 'Pushing to container registry...', group_id: 'g-deploy' }),
    entry({ text: 'Rolling update: 3/3 replicas healthy', group_id: 'g-deploy' }),
    entry({ severity: 'info', text: 'Deployment v2.4.1 complete ✓', group_id: 'g-deploy' }),
    entry({ type: 'group', group_id: 'g-deploy', group_action: 'close' }),
    entry({ severity: 'info', text: 'Health check passed (200 OK)' }),
    entry({ severity: 'debug', text: 'Metrics endpoint registered at /metrics' }),
    entry({ severity: 'info', text: 'WebSocket hub ready — 0 viewers connected' }),
    entry({ severity: 'error', text: 'Query timeout after 30000ms on postgres://db.prod:5432/app' }),
    entry({ severity: 'info', text: 'Retry succeeded — query completed in 450ms' }),
    entry({ severity: 'info', text: 'API ready: https://api.example.com/v2' }),
  ]);
}

// ─── Scenario 2: Custom Renderers ────────────────────────────────────

export async function setupCustomRenderers(url: string) {
  await postEntries(url, [
    entry({ text: 'Top 5 slowest endpoints:' }),
    entry({
      type: 'custom',
      custom_type: 'table',
      custom_data: {
        headers: ['Route', 'Method', 'p95', 'Calls'],
        rows: [
          ['GET /api/search', 'GET', '230ms', '12,340'],
          ['POST /api/upload', 'POST', '450ms', '3,210'],
          ['GET /api/users/:id', 'GET', '25ms', '45,600'],
          ['PUT /api/settings', 'PUT', '40ms', '890'],
          ['GET /api/feed', 'GET', '120ms', '28,100'],
        ],
      },
    }),
    entry({ text: 'Server metrics:' }),
    entry({
      type: 'custom',
      custom_type: 'kv',
      custom_data: {
        pairs: {
          'CPU Usage': '42%',
          Memory: '1.3 GB / 4 GB',
          'Disk I/O': '23 MB/s',
          'Active Connections': '847',
          Uptime: '14d 6h 23m',
        },
      },
    }),
    entry({
      type: 'custom',
      custom_type: 'progress',
      custom_data: { current: 73, total: 100, label: 'Building project...' },
    }),
    entry({
      type: 'state',
      state_key: '_chart.cpu',
      state_value: {
        type: 'sparkline',
        title: 'CPU %',
        values: [23, 45, 38, 67, 55, 42, 58, 71, 63, 48],
      },
    }),
    entry({
      type: 'state',
      state_key: '_chart.memory',
      state_value: {
        type: 'bar',
        title: 'Memory MB',
        values: [512, 680, 720, 690, 780, 850, 820, 900],
      },
    }),
  ]);
}

// ─── Scenario 3: Error with Stack Trace ──────────────────────────────

export async function setupErrorTrace(url: string) {
  await postEntries(url, [
    entry({
      severity: 'error',
      text: 'Unhandled exception in request handler',
      exception: {
        type: 'QueryTimeoutError',
        message: 'Query timeout after 30000ms',
        stackTrace: [
          { location: { uri: 'src/db/pool.ts', line: 142, symbol: 'Pool.query' } },
          { location: { uri: 'src/handlers/search.ts', line: 58, symbol: 'handleSearch' } },
          { location: { uri: 'src/middleware/auth.ts', line: 23, symbol: 'authenticate' } },
          { location: { uri: 'src/server.ts', line: 89, symbol: 'onRequest' } },
          {
            location: { uri: 'node_modules/hono/router.ts', line: 201, symbol: 'dispatch' },
            isVendor: true,
          },
        ],
        cause: {
          type: 'ConnectionError',
          message: 'ETIMEDOUT: connection timed out to 10.0.1.42:5432',
          stackTrace: [
            { location: { uri: 'src/db/connection.ts', line: 34, symbol: 'connect' } },
            {
              location: { uri: 'node_modules/pg/client.ts', line: 112, symbol: 'Client.connect' },
              isVendor: true,
            },
          ],
        },
      },
    }),
  ]);
}

// ─── Scenario 4: Multiple Sessions ──────────────────────────────────

export async function setupMultipleSessions(url: string) {
  const sessions = [
    { id: 'api-server-01', app: { name: 'API Server', version: '2.4.1' } },
    { id: 'worker-queue', app: { name: 'Job Worker', version: '1.8.0' } },
    { id: 'web-frontend', app: { name: 'Web App', version: '3.1.0' } },
  ];
  const entries = sessions.flatMap((s) => [
    entry({
      session_id: s.id,
      application: s.app,
      type: 'session',
      session_action: 'start',
    }),
    entry({ session_id: s.id, application: s.app, text: `${s.app.name} started` }),
    entry({
      session_id: s.id,
      application: s.app,
      severity: 'debug',
      text: 'Initializing modules...',
    }),
  ]);
  await postEntries(url, entries);
}

// ─── Scenario 5: Sticky Grouping ────────────────────────────────────

export async function setupStickyGrouping(url: string) {
  const gid = 'req-batch';
  await postEntries(url, [
    entry({
      sticky: true,
      type: 'group',
      group_id: gid,
      group_action: 'open',
      group_label: 'Request Batch #4821',
    }),
    entry({ text: 'Processing item 1/50', group_id: gid }),
    entry({ text: 'Processing item 2/50', group_id: gid }),
    entry({ severity: 'warning', text: 'Item 3 skipped: invalid format', group_id: gid }),
    entry({ text: 'Processing item 4/50', group_id: gid }),
    entry({ text: 'Processing item 5/50', group_id: gid }),
    entry({ severity: 'info', text: 'Checkpoint saved at item 5', group_id: gid }),
  ]);
}

// ─── Scenario 6: State Panel ─────────────────────────────────────────

export async function setupStatePanel(url: string) {
  await postEntries(url, [
    entry({ type: 'state', state_key: 'deployment_version', state_value: 'v2.4.1' }),
    entry({ type: 'state', state_key: 'healthy_replicas', state_value: 3 }),
    entry({ type: 'state', state_key: 'last_deploy', state_value: '2026-01-15T10:15:00Z' }),
    entry({ type: 'state', state_key: 'db_pool_size', state_value: 5 }),
    entry({ type: 'state', state_key: 'cache_hit_rate', state_value: '55%' }),
    entry({ type: 'state', state_key: 'active_users', state_value: 1247 }),
  ]);
}

// ─── Scenario 7: HTTP Requests ───────────────────────────────────────

export async function setupHttpRequests(url: string) {
  await postEntries(url, [
    entry({
      type: 'custom',
      custom_type: 'http_request',
      custom_data: {
        method: 'POST',
        url: 'https://api.example.com/v2/users',
        status: 201,
        duration: 145,
        request: {
          headers: { 'Content-Type': 'application/json' },
          body: '{"name":"Alice"}',
        },
        response: {
          headers: { 'Content-Type': 'application/json' },
          body: '{"id":42,"name":"Alice"}',
        },
      },
    }),
    entry({
      type: 'custom',
      custom_type: 'http_request',
      custom_data: {
        method: 'GET',
        url: 'https://api.example.com/v2/search?q=logs',
        status: 200,
        duration: 230,
        request: { headers: { Accept: 'application/json' } },
        response: {
          headers: { 'Content-Type': 'application/json' },
          body: '{"results":[],"total":0}',
        },
      },
    }),
    entry({
      type: 'custom',
      custom_type: 'http_request',
      custom_data: {
        method: 'DELETE',
        url: 'https://api.example.com/v2/sessions/old',
        status: 500,
        duration: 5023,
        request: {},
        response: { body: '{"error":"Internal server error"}' },
      },
    }),
  ]);
}

// ─── Exported Scenario List ──────────────────────────────────────────

export interface Scenario {
  name: string;
  description: string;
  setup: (url: string) => Promise<void>;
}

export const scenarios: Scenario[] = [
  { name: '01-app-overview', description: 'Mixed severity logs with groups', setup: setupOverview },
  { name: '02-custom-renderers', description: 'Table, KV, progress, chart', setup: setupCustomRenderers },
  { name: '03-error-stack-trace', description: 'Error with expanded stack trace', setup: setupErrorTrace },
  { name: '04-session-selection', description: 'Multiple sessions in sidebar', setup: setupMultipleSessions },
  { name: '05-filter-bar', description: 'Active filters visible', setup: async () => {} },
  { name: '06-sticky-grouping', description: 'Sticky group headers', setup: setupStickyGrouping },
  { name: '07-state-panel', description: 'State key-value pairs', setup: setupStatePanel },
  { name: '08-http-requests', description: 'HTTP request renderer', setup: setupHttpRequests },
];
