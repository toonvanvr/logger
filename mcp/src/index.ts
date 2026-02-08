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

// ─── Tool: logger.query ─────────────────────────────────────────────

server.tool(
  'logger.query',
  'Query Logger server data: health status, sessions, session state, or log entries with filters',
  {
    scope: z.enum(['health', 'sessions', 'state', 'logs']).optional()
      .describe('What to query: health (server status), sessions (active sessions), state (session state), logs (log entries). Defaults to logs.'),
    sessionId: z.string().optional()
      .describe('Session ID — required for scope=state, optional filter for scope=logs'),
    severity: z.string().optional()
      .describe('Filter by severity (scope=logs only): verbose, debug, info, warn, error, fatal'),
    from: z.string().optional()
      .describe('Start of time range, ISO 8601 (scope=logs only)'),
    to: z.string().optional()
      .describe('End of time range, ISO 8601 (scope=logs only)'),
    limit: z.number().int().min(1).max(1000).optional()
      .describe('Max entries to return, default 20 (scope=logs only)'),
    search: z.string().optional()
      .describe('Full-text search string (scope=logs only)'),
  },
  async (args) => {
    const scope = args.scope ?? 'logs';

    switch (scope) {
      case 'health':
        return textResult(await fetchJson('/api/v1/health'));

      case 'sessions':
        return textResult(await fetchJson('/api/v1/sessions'));

      case 'state': {
        if (!args.sessionId) {
          return textResult({ error: 'sessionId is required for scope=state' });
        }
        try {
          return textResult(await fetchJson(`/api/v1/sessions/${args.sessionId}/state`));
        } catch (err) {
          return textResult({ error: 'Failed to retrieve session state', detail: err instanceof Error ? err.message : String(err) });
        }
      }

      case 'logs':
      default: {
        const queryBody: Record<string, unknown> = { limit: args.limit ?? 20 };
        if (args.sessionId) queryBody.sessionId = args.sessionId;
        if (args.severity) queryBody.severity = args.severity;
        if (args.from) queryBody.from = args.from;
        if (args.to) queryBody.to = args.to;
        if (args.search) queryBody.search = args.search;

        try {
          return textResult(await fetchJson('/api/v1/query', {
            method: 'POST',
            headers: { 'content-type': 'application/json' },
            body: JSON.stringify(queryBody),
          }));
        } catch {
          const health = await fetchJson('/api/v1/health');
          return textResult({ note: 'Query endpoint not available. Showing health.', health, query: queryBody });
        }
      }
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

// ─── Connect ─────────────────────────────────────────────────────────

const transport = new StdioServerTransport();
await server.connect(transport);
