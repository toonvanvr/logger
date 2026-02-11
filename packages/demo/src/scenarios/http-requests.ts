import { Logger } from '@logger/client'

const delay = (ms: number) => new Promise(r => setTimeout(r, ms))

export async function runHttpRequests() {
  const logger = new Logger({ app: 'demo-http', transport: 'http' })

  try {
    // ── 1. Successful GET (fast, 45ms) ─────────────────────────────
    logger.http('GET', 'https://api.example.com/api/v1/users/profile', {
      status: 200,
      duration_ms: 45,
      request_headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer eyJhbGciOiJIUzI1NiJ9.eyJ1c2VyIjoiYWxpY2UifQ.abc',
        'X-Request-ID': 'req-a1b2c3',
      },
      response_headers: {
        'Content-Type': 'application/json; charset=utf-8',
        'X-Request-ID': 'req-a1b2c3',
        'Cache-Control': 'private, max-age=60',
      },
      response_body: JSON.stringify({
        id: 42,
        name: 'Alice Johnson',
        email: 'alice@example.com',
        role: 'admin',
        created_at: '2025-09-15T08:30:00Z',
      }),
      request_id: 'req-a1b2c3',
    })
    await delay(400)

    // ── 2. POST with JSON body ─────────────────────────────────────
    logger.http('POST', 'https://api.example.com/api/v1/orders', {
      status: 201,
      duration_ms: 132,
      request_headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer eyJhbGciOiJIUzI1NiJ9.eyJ1c2VyIjoiYWxpY2UifQ.abc',
        'Idempotency-Key': 'idem-7f3a9c',
      },
      request_body: JSON.stringify({
        product_id: 'prod-8812',
        quantity: 3,
        shipping_address: {
          street: '742 Evergreen Terrace',
          city: 'Springfield',
          state: 'IL',
          zip: '62704',
        },
      }),
      response_headers: {
        'Content-Type': 'application/json',
        'Location': '/api/v1/orders/ord-9921',
      },
      response_body: JSON.stringify({
        id: 'ord-9921',
        status: 'confirmed',
        total: 89.97,
        currency: 'USD',
      }),
      request_id: 'req-d4e5f6',
    })
    await delay(400)

    // ── 3. Failed request (500) with error response body ───────────
    logger.http('POST', 'https://api.example.com/api/v1/orders/batch', {
      status: 500,
      duration_ms: 1247,
      request_headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer eyJhbGciOiJIUzI1NiJ9.eyJ1c2VyIjoiYWxpY2UifQ.abc',
      },
      request_body: JSON.stringify({ ids: ['ord-1001', 'ord-1002', 'ord-1003'] }),
      response_headers: {
        'Content-Type': 'application/json',
        'X-Error-Code': 'POOL_EXHAUSTED',
      },
      response_body: JSON.stringify({
        error: 'Connection pool exhausted',
        details: 'All 10 connections in the pool are in use. Max wait time exceeded after 1200ms.',
        trace_id: 'trace-88af3c',
      }),
      request_id: 'req-g7h8i9',
    })
    await delay(400)

    // ── 4. Timeout (no response, is_error=true) ────────────────────
    logger.http('GET', 'https://api.example.com/api/v1/reports/annual', {
      duration_ms: 30000,
      is_error: true,
      request_headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer eyJhbGciOiJIUzI1NiJ9.eyJ1c2VyIjoiYWxpY2UifQ.abc',
      },
      started_at: new Date(Date.now() - 30000).toISOString(),
      request_id: 'req-j0k1l2',
    })
    await delay(400)

    // ── 5. Slow request with TTFB breakdown ────────────────────────
    logger.http('GET', 'https://api.example.com/api/v1/analytics/dashboard', {
      status: 200,
      duration_ms: 2340,
      request_headers: {
        'Accept': 'application/json',
        'Cache-Control': 'no-cache',
      },
      response_headers: {
        'Content-Type': 'application/json',
        'Server-Timing': 'db;dur=1850, render;dur=340',
        'X-Response-Time': '2340ms',
      },
      response_body: JSON.stringify({
        active_users: 1523,
        revenue_mtd: 142850.75,
        orders_today: 312,
      }),
      request_id: 'req-m3n4o5',
    })
    await delay(400)

    // ── 6. Async lifecycle: send pending, then complete ────────────
    logger.info('Starting async request lifecycle...')
    logger.custom('http_request', {
      method: 'PUT',
      url: 'https://api.example.com/admin/orders/ord-9921/ship',
      started_at: new Date().toISOString(),
      request_headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer eyJhbGciOiJIUzI1NiJ9.eyJ1c2VyIjoiYWxpY2UifQ.abc',
      },
      request_body: JSON.stringify({ carrier: 'fedex', tracking: 'FX-998877' }),
      request_id: 'req-p6q7r8',
    }, { id: 'async-ship-1', replace: true })

    await delay(1500)

    // Complete the async request
    logger.custom('http_request', {
      method: 'PUT',
      url: 'https://api.example.com/admin/orders/ord-9921/ship',
      status: 200,
      status_text: 'OK',
      duration_ms: 1480,
      started_at: new Date(Date.now() - 1480).toISOString(),
      request_headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer eyJhbGciOiJIUzI1NiJ9.eyJ1c2VyIjoiYWxpY2UifQ.abc',
      },
      request_body: JSON.stringify({ carrier: 'fedex', tracking: 'FX-998877' }),
      response_headers: {
        'Content-Type': 'application/json',
      },
      response_body: JSON.stringify({ status: 'shipped', tracking_url: 'https://fedex.com/track/FX-998877' }),
      request_id: 'req-p6q7r8',
      is_error: false,
    }, { id: 'async-ship-1', replace: true })
    await delay(400)

    // ── 7. Rate limited (429) with Retry-After header ──────────────
    logger.http('POST', 'https://api.example.com/api/graphql', {
      status: 429,
      duration_ms: 12,
      request_headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer eyJhbGciOiJIUzI1NiJ9.eyJ1c2VyIjoiYWxpY2UifQ.abc',
      },
      request_body: JSON.stringify({
        query: '{ users(first: 100) { id name email } }',
      }),
      response_headers: {
        'Content-Type': 'application/json',
        'Retry-After': '30',
        'X-RateLimit-Remaining': '0',
        'X-RateLimit-Reset': new Date(Date.now() + 30000).toISOString(),
      },
      response_body: JSON.stringify({
        error: 'Too Many Requests',
        message: 'Rate limit exceeded. Please retry after 30 seconds.',
      }),
      request_id: 'req-s9t0u1',
    })
    await delay(400)

    // ── 8. WebSocket upgrade (101) ─────────────────────────────────
    logger.http('GET', 'wss://api.example.com/ws/live-updates', {
      status: 101,
      duration_ms: 8,
      request_headers: {
        'Connection': 'Upgrade',
        'Upgrade': 'websocket',
        'Sec-WebSocket-Key': 'dGhlIHNhbXBsZSBub25jZQ==',
        'Sec-WebSocket-Version': '13',
      },
      response_headers: {
        'Connection': 'Upgrade',
        'Upgrade': 'websocket',
        'Sec-WebSocket-Accept': 's3pPLMBiTxaQ9kYGzzhZRbK+xOo=',
      },
      request_id: 'req-v2w3x4',
    })
    await delay(400)

    // ── 9. Large payload (multipart, 2MB) ──────────────────────────
    logger.http('POST', 'https://api.example.com/api/v1/uploads/avatar', {
      status: 200,
      duration_ms: 3200,
      request_headers: {
        'Content-Type': 'multipart/form-data; boundary=----WebKitFormBoundary7MA4YWxk',
        'Authorization': 'Bearer eyJhbGciOiJIUzI1NiJ9.eyJ1c2VyIjoiYWxpY2UifQ.abc',
      },
      response_headers: {
        'Content-Type': 'application/json',
      },
      response_body: JSON.stringify({
        url: 'https://cdn.example.com/avatars/42/large.webp',
        size: 2097152,
        format: 'webp',
      }),
      request_id: 'req-y5z6a7',
    })
    await delay(400)

    // ── 10. Multiple correlated requests (shared request_id) ───────
    const correlationId = 'correlation-b8c9d0'

    logger.http('POST', 'https://api.example.com/auth/token', {
      status: 200,
      duration_ms: 85,
      request_headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      request_body: 'grant_type=client_credentials&client_id=demo-app',
      response_headers: {
        'Content-Type': 'application/json',
      },
      response_body: JSON.stringify({
        access_token: 'eyJhbGciOiJSUzI1NiJ9.eyJzY29wZSI6InJlYWQifQ.sig',
        token_type: 'Bearer',
        expires_in: 3600,
      }),
      request_id: correlationId,
    })
    await delay(200)

    logger.http('GET', 'https://api.example.com/api/v1/users?page=1&per_page=25', {
      status: 200,
      duration_ms: 67,
      request_headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer eyJhbGciOiJSUzI1NiJ9.eyJzY29wZSI6InJlYWQifQ.sig',
      },
      response_headers: {
        'Content-Type': 'application/json',
        'X-Total-Count': '142',
        'Link': '</api/v1/users?page=2&per_page=25>; rel="next"',
      },
      response_body: JSON.stringify({
        data: [
          { id: 1, name: 'Alice', role: 'admin' },
          { id: 2, name: 'Bob', role: 'user' },
        ],
        meta: { page: 1, per_page: 25, total: 142 },
      }),
      request_id: correlationId,
    })
    await delay(200)

    logger.http('PATCH', 'https://api.example.com/api/v1/users/2', {
      status: 200,
      duration_ms: 34,
      request_headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer eyJhbGciOiJSUzI1NiJ9.eyJzY29wZSI6InJlYWQifQ.sig',
      },
      request_body: JSON.stringify({ role: 'moderator' }),
      response_headers: {
        'Content-Type': 'application/json',
      },
      response_body: JSON.stringify({
        id: 2,
        name: 'Bob',
        role: 'moderator',
        updated_at: new Date().toISOString(),
      }),
      request_id: correlationId,
    })
    await delay(300)

    logger.info('HTTP request demo complete — 10 scenarios sent')

    await logger.flush()
  } finally {
    await logger.close()
  }
}
