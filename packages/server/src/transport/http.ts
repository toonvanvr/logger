import { ingestEntry, processEntry } from './ingest';
import type { ServerDeps } from './types';

// ─── Constants ───────────────────────────────────────────────────────

const MAX_UPLOAD_SIZE = 16 * 1024 * 1024; // 16 MB
const startTime = Date.now();

// ─── Auth Helper ─────────────────────────────────────────────────────

function checkAuth(req: Request, apiKey: string | null): Response | null {
  if (!apiKey) return null;

  const authHeader = req.headers.get('authorization');
  const apiKeyHeader = req.headers.get('x-api-key');

  if (authHeader === `Bearer ${apiKey}` || apiKeyHeader === apiKey) {
    return null;
  }

  return Response.json({ ok: false, error: 'Unauthorized' }, { status: 401 });
}

// ─── Route Setup ─────────────────────────────────────────────────────

export function setupHttpRoutes(deps: ServerDeps): Record<string, any> {
  const { config, rateLimiter, ringBuffer, sessionManager, wsHub, lokiForwarder, fileStore, rpcBridge } = deps;

  return {
    '/health': {
      GET: () => Response.json({ ok: true }),
    },

    '/api/v1/health': {
      GET: (req: Request) => {
        const authError = checkAuth(req, config.apiKey);
        if (authError) return authError;

        const lokiHealth = lokiForwarder.getHealth();
        return Response.json({
          ok: true,
          uptime: Math.floor((Date.now() - startTime) / 1000),
          connections: wsHub.getViewerCount(),
          buffer: {
            entries: ringBuffer.size,
            bytes: ringBuffer.byteEstimate,
          },
          loki: lokiHealth,
          sessions: sessionManager.getSessions().length,
          rpcPending: rpcBridge.getPendingCount(),
        });
      },
    },

    '/api/v1/log': {
      POST: async (req: Request) => {
        const authError = checkAuth(req, config.apiKey);
        if (authError) return authError;

        let body: unknown;
        try {
          body = await req.json();
        } catch {
          return Response.json({ ok: false, error: 'Invalid JSON' }, { status: 400 });
        }

        const processed = processEntry(body, deps);
        if (!processed.ok) {
          return Response.json({ ok: false, error: processed.error }, { status: 400 });
        }

        const entry = processed.entry;

        if (!rateLimiter.tryConsume(entry.session_id)) {
          return Response.json({ ok: false, error: 'Rate limit exceeded' }, { status: 429 });
        }

        ingestEntry(entry, deps);
        return Response.json({ ok: true, id: entry.id });
      },
    },

    '/api/v1/logs': {
      POST: async (req: Request) => {
        const authError = checkAuth(req, config.apiKey);
        if (authError) return authError;

        let body: unknown;
        try {
          body = await req.json();
        } catch {
          return Response.json({ ok: false, error: 'Invalid JSON' }, { status: 400 });
        }

        if (!body || typeof body !== 'object' || !Array.isArray((body as any).entries)) {
          return Response.json({ ok: false, error: 'Expected { entries: [...] }' }, { status: 400 });
        }

        const rawEntries = (body as any).entries as unknown[];
        if (rawEntries.length === 0 || rawEntries.length > 1000) {
          return Response.json({ ok: false, error: 'Batch must contain 1 to 1000 entries' }, { status: 400 });
        }

        const ids: string[] = [];
        for (const rawEntry of rawEntries) {
          const processed = processEntry(rawEntry, deps);
          if (!processed.ok) continue;

          const entry = processed.entry;
          if (!rateLimiter.tryConsume(entry.session_id)) continue;

          ingestEntry(entry, deps);
          ids.push(entry.id);
        }

        return Response.json({ ok: true, count: ids.length, ids });
      },
    },

    '/api/v1/upload': {
      POST: async (req: Request) => {
        const authError = checkAuth(req, config.apiKey);
        if (authError) return authError;

        let formData: FormData;
        try {
          formData = await req.formData();
        } catch {
          return Response.json({ ok: false, error: 'Invalid multipart data' }, { status: 400 });
        }

        const file = formData.get('file');
        if (!file || !(file instanceof File)) {
          return Response.json({ ok: false, error: 'Missing file field' }, { status: 400 });
        }

        if (file.size > MAX_UPLOAD_SIZE) {
          return Response.json({ ok: false, error: 'File too large' }, { status: 413 });
        }

        const sessionId = formData.get('session_id');
        if (!sessionId || typeof sessionId !== 'string') {
          return Response.json({ ok: false, error: 'Missing session_id' }, { status: 400 });
        }

        const label = formData.get('label');

        try {
          const bytes = new Uint8Array(await file.arrayBuffer());
          const ref = await fileStore.store(
            sessionId,
            bytes,
            file.type || 'application/octet-stream',
            typeof label === 'string' ? label : undefined,
          );
          return Response.json({ ok: true, ref });
        } catch (err) {
          console.error('[HTTP] File upload error:', err);
          return Response.json({ ok: false, error: 'Internal server error' }, { status: 500 });
        }
      },
    },

    '/api/v1/sessions': {
      GET: (req: Request) => {
        const authError = checkAuth(req, config.apiKey);
        if (authError) return authError;

        return Response.json(sessionManager.getSessions());
      },
    },

    '/log': {
      POST: async (req: Request) => {
        let body: unknown;
        try {
          body = await req.json();
        } catch {
          return Response.json({ ok: false, error: 'Invalid JSON' }, { status: 400 });
        }

        const processed = processEntry(body, deps);
        if (!processed.ok) {
          return Response.json({ ok: false, error: processed.error }, { status: 400 });
        }

        const entry = processed.entry;

        if (!rateLimiter.tryConsume(entry.session_id)) {
          return Response.json({ ok: false, error: 'Rate limit exceeded' }, { status: 429 });
        }

        ingestEntry(entry, deps);
        return Response.json({ ok: true, id: entry.id });
      },
    },
  };
}
