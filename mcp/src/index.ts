import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { z } from 'zod';

// ─── Configuration ───────────────────────────────────────────────────

const LOGGER_URL = process.env.LOGGER_URL ?? 'http://localhost:8080';
const API_KEY = process.env.LOGGER_API_KEY ?? '';

// ─── Helpers ─────────────────────────────────────────────────────────

function authHeaders(): Record<string, string> {
  if (!API_KEY) return {};
  return { 'x-api-key': API_KEY };
}

async function fetchJson(path: string, init?: RequestInit): Promise<unknown> {
  const url = `${LOGGER_URL}${path}`;
  const res = await fetch(url, {
    ...init,
    headers: {
      ...authHeaders(),
      ...(init?.headers as Record<string, string> | undefined),
    },
  });
  if (!res.ok) {
    const body = await res.text().catch(() => '');
    throw new Error(`HTTP ${res.status} from ${path}: ${body}`);
  }
  return res.json();
}

function textResult(data: unknown): { content: { type: 'text'; text: string }[] } {
  return { content: [{ type: 'text' as const, text: JSON.stringify(data, null, 2) }] };
}

// ─── Server ──────────────────────────────────────────────────────────

const server = new McpServer({
  name: 'logger-mcp',
  version: '0.1.0',
});

// ─── Tool: logger.health ────────────────────────────────────────────

server.tool(
  'logger.health',
  'Get Logger server health status including connections, buffer usage, and Loki state',
  {},
  async () => {
    const data = await fetchJson('/api/v1/health');
    return textResult(data);
  },
);

// ─── Tool: logger.sessions ──────────────────────────────────────────

server.tool(
  'logger.sessions',
  'List active logging sessions with app names, log counts, and status',
  {},
  async () => {
    const data = await fetchJson('/api/v1/sessions');
    return textResult(data);
  },
);

// ─── Tool: logger.query ─────────────────────────────────────────────

server.tool(
  'logger.query',
  'Query log entries with optional filters for session, severity, time range, limit, and text search',
  {
    sessionId: z.string().optional().describe('Filter by session ID'),
    severity: z.string().optional().describe('Filter by severity level (e.g. info, warn, error)'),
    from: z.string().optional().describe('Start of time range (ISO 8601)'),
    to: z.string().optional().describe('End of time range (ISO 8601)'),
    limit: z.number().int().min(1).max(1000).optional().describe('Max entries to return (default 100)'),
    search: z.string().optional().describe('Full-text search string'),
  },
  async (args) => {
    const params = new URLSearchParams();
    if (args.sessionId) params.set('sessionId', args.sessionId);
    if (args.severity) params.set('severity', args.severity);
    if (args.from) params.set('from', args.from);
    if (args.to) params.set('to', args.to);
    if (args.limit) params.set('limit', String(args.limit));
    if (args.search) params.set('search', args.search);

    // The server ring buffer is queried via the /api/v1/health endpoint's ring buffer.
    // For direct query, POST to /api/v1/logs or use the ring buffer via a query endpoint.
    // Since there's no dedicated query GET endpoint, we query the ring buffer via WS or
    // build query params. For now, use the ring buffer query params convention.
    const qs = params.toString();
    const path = `/api/v1/sessions${qs ? `?${qs}` : ''}`;

    // Fallback: build a POST body and send to a query-compatible endpoint.
    // The server exposes ring buffer via WS. For REST, we hit the sessions endpoint
    // and filter client-side, or call a dedicated query path if available.
    // Using a simple approach: fetch all sessions, then filter entries from ring buffer.
    // Best approach with current API: POST to /api/v1/log won't help, so we pass
    // query params to the health endpoint as a workaround - this needs a real query API.

    // Direct ring buffer query via query params on /api/v1/logs
    const queryBody: Record<string, unknown> = {};
    if (args.sessionId) queryBody.sessionId = args.sessionId;
    if (args.severity) queryBody.severity = args.severity;
    if (args.from) queryBody.from = args.from;
    if (args.to) queryBody.to = args.to;
    if (args.limit) queryBody.limit = args.limit;
    if (args.search) queryBody.search = args.search;

    try {
      // Try a dedicated query endpoint first
      const data = await fetchJson('/api/v1/query', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify(queryBody),
      });
      return textResult(data);
    } catch {
      // Fallback: return health + sessions info as context
      const health = await fetchJson('/api/v1/health');
      return textResult({
        note: 'Dedicated query endpoint not available. Showing server health instead. Use logger.recent for recent entries.',
        health,
        query: queryBody,
      });
    }
  },
);

// ─── Tool: logger.send ──────────────────────────────────────────────

server.tool(
  'logger.send',
  'Send a log entry to the Logger server',
  {
    severity: z.string().describe('Log severity: verbose, debug, info, warn, error, fatal'),
    text: z.string().describe('Log message text'),
    session: z.string().optional().describe('Session ID (optional, server may assign default)'),
  },
  async (args) => {
    const body: Record<string, unknown> = {
      type: 'text',
      severity: args.severity,
      text: args.text,
      timestamp: new Date().toISOString(),
    };
    if (args.session) {
      body.session_id = args.session;
    }
    const data = await fetchJson('/api/v1/log', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify(body),
    });
    return textResult(data);
  },
);

// ─── Tool: logger.recent ────────────────────────────────────────────

server.tool(
  'logger.recent',
  'Get the most recent log entries',
  {
    count: z.number().int().min(1).max(500).optional().describe('Number of recent entries (default 20)'),
    sessionId: z.string().optional().describe('Filter by session ID'),
  },
  async (args) => {
    const queryBody: Record<string, unknown> = {
      limit: args.count ?? 20,
    };
    if (args.sessionId) queryBody.sessionId = args.sessionId;

    try {
      const data = await fetchJson('/api/v1/query', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify(queryBody),
      });
      return textResult(data);
    } catch {
      // Fallback: health summary if query endpoint unavailable
      const health = await fetchJson('/api/v1/health');
      return textResult({
        note: 'Query endpoint not available. Showing server health as summary.',
        health,
      });
    }
  },
);

// ─── Tool: logger.rpc ───────────────────────────────────────────────

server.tool(
  'logger.rpc',
  'Invoke an RPC method on a connected client session',
  {
    sessionId: z.string().describe('Target session ID'),
    method: z.string().describe('RPC method name to invoke'),
    args: z.unknown().optional().describe('Arguments to pass to the RPC method'),
  },
  async (args) => {
    // RPC invocation requires WS; proxy via HTTP if an RPC endpoint exists.
    try {
      const data = await fetchJson('/api/v1/rpc', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({
          sessionId: args.sessionId,
          method: args.method,
          args: args.args,
        }),
      });
      return textResult(data);
    } catch (err) {
      return textResult({
        error: 'RPC invocation failed. The server may not expose an HTTP RPC proxy.',
        detail: err instanceof Error ? err.message : String(err),
      });
    }
  },
);

// ─── Tool: logger.state ─────────────────────────────────────────────

server.tool(
  'logger.state',
  'Get current state key-value pairs for a session',
  {
    sessionId: z.string().describe('Session ID to retrieve state for'),
  },
  async (args) => {
    try {
      const data = await fetchJson(`/api/v1/sessions/${args.sessionId}/state`);
      return textResult(data);
    } catch (err) {
      return textResult({
        error: 'Failed to retrieve session state',
        detail: err instanceof Error ? err.message : String(err),
      });
    }
  },
);

// ─── Connect ─────────────────────────────────────────────────────────

const transport = new StdioServerTransport();
await server.connect(transport);
