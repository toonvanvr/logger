import { ingestEntry, processEntry } from './ingest';
import type { ServerDeps } from './types';

// ─── Constants ───────────────────────────────────────────────────────

const MAX_LINE_SIZE = 16 * 1024 * 1024; // 16 MB
const IDLE_TIMEOUT_SECONDS = 300; // 5 minutes

// ─── TCP Transport ───────────────────────────────────────────────────

interface TcpState {
  buffer: string;
  authenticated: boolean;
}

export async function setupTcp(deps: ServerDeps): Promise<void> {
  const { config } = deps;

  Bun.listen<TcpState>({
    hostname: config.host,
    port: config.tcpPort,
    socket: {
      open(socket) {
        socket.data = {
          buffer: '',
          authenticated: !config.apiKey,
        };
        socket.timeout(IDLE_TIMEOUT_SECONDS);
      },

      data(socket, data) {
        const state = socket.data;
        state.buffer += data.toString();

        // Process complete lines (NDJSON: one JSON object per \n)
        let newlineIndex: number;
        while ((newlineIndex = state.buffer.indexOf('\n')) !== -1) {
          const line = state.buffer.slice(0, newlineIndex);
          state.buffer = state.buffer.slice(newlineIndex + 1);

          if (line.length > MAX_LINE_SIZE) {
            console.warn('[TCP] Line exceeds 16MB limit, dropping');
            continue;
          }

          // Auth check: first line must be `AUTH <key>\n`
          if (!state.authenticated) {
            if (line.startsWith('AUTH ') && line.slice(5) === config.apiKey) {
              state.authenticated = true;
            } else {
              socket.end();
              return;
            }
            continue;
          }

          if (line.length === 0) continue;

          let parsed: unknown;
          try {
            parsed = JSON.parse(line);
          } catch {
            continue; // skip malformed lines
          }

          const result = processEntry(parsed, deps);
          if (!result.ok) continue;

          ingestEntry(result.entry, deps);
        }

        // Guard against unbounded buffer growth
        if (state.buffer.length > MAX_LINE_SIZE) {
          console.warn('[TCP] Buffer exceeds 16MB, clearing');
          state.buffer = '';
        }
      },

      close() {},

      error(_socket, err) {
        console.error('[TCP] Socket error:', err);
      },

      timeout(socket) {
        socket.end();
      },
    },
  });

  console.log(`TCP server listening on ${config.host}:${config.tcpPort}`);
}
