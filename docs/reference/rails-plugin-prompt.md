# Rails Logger Plugin Development Prompt

## Context

**Logger** is a real-time structured log viewer for application debugging. Applications push structured logs via a client SDK to a Bun-based server, which stores them in a ring buffer and forwards to Grafana Loki. A Flutter desktop app provides live log viewing with rich rendering.

Logger's HTTP Request Widget renders HTTP lifecycle entries with: method, URL, status, timing (including TTFB), request/response headers and bodies, request ID correlation, and async lifecycle (pending → complete via entry replacement).

This prompt specifies a Rails gem (`logger-rails`) that automatically instruments Rails applications to send structured HTTP request logs to Logger, fully compatible with the existing widget system.

### Wire Protocol Reference

Logger receives `EventMessage` entries with a `widget` field. The HTTP Request Widget schema (from `packages/shared/src/widget.ts`):

```typescript
HttpRequestWidget = {
  type: 'http_request',          // discriminator
  method: string,                // HTTP method (GET, POST, etc.)
  url: string,                   // full URL
  request_headers?: Record<string, string>,
  request_body?: string,
  request_body_size?: number,    // bytes
  status?: number,               // HTTP status code
  status_text?: string,          // e.g., "OK", "Internal Server Error"
  response_headers?: Record<string, string>,
  response_body?: string,
  response_body_size?: number,   // bytes
  started_at?: string,           // ISO 8601
  duration_ms?: number,          // total roundtrip
  ttfb_ms?: number,              // time to first byte
  request_id?: string,           // correlation ID
  content_type?: string,         // response content type
  is_error?: boolean,            // true for failures
}
```

The Logger server HTTP API accepts entries at `POST /api/v2/events` with JSON body. Entry stacking (lifecycle updates) uses `{ id: stableId, replace: true }` to replace-in-place.

### Client SDK Pattern (TypeScript Reference)

The TypeScript client SDK provides:

```typescript
const logger = new Logger({ server: 'http://localhost:8080', app: 'my-app' })

// One-shot (request + response in single entry)
logger.http('GET', '/api/users', {
  status: 200, duration_ms: 45,
  request_headers: { 'Authorization': 'Bearer ...' },
  response_headers: { 'Content-Type': 'application/json' },
  response_body: '{"users": [...]}',
  request_id: 'req-abc123',
})

// Async lifecycle (pending → complete)
logger.http('POST', '/api/orders', {
  request_headers: { 'Content-Type': 'application/json' },
  request_body: '{"product_id": "prod-123"}',
  started_at: new Date().toISOString(),
}, { id: 'req-xyz', replace: true })  // sends PENDING entry

// ... later, when response arrives:
logger.http('POST', '/api/orders', {
  status: 201, duration_ms: 132,
  request_headers: { ... },
  response_headers: { ... },
  response_body: '{"id": "ord-456"}',
  request_id: 'req-xyz',
}, { id: 'req-xyz', replace: true })  // replaces with COMPLETE entry
```

Auto-severity: status ≥ 500 → `error`, status ≥ 400 → `warning`, else `info`.

---

## Goal

Create a Rails gem **`logger-rails`** that automatically instruments Rails applications to send structured HTTP request logs to Logger. The gem should feel native to Rails (convention over configuration, initializer-based setup, engine auto-discovery) while mapping precisely to Logger's HTTP Request Widget schema.

### Parallel Goal: NestJS/TypeScript Package

After the Rails gem, create an equivalent `@logger/nestjs` package for NestJS applications. The TypeScript client SDK already exists — the NestJS package wraps it with framework-specific middleware and decorators. Note differences from Rails where applicable.

---

## Features

### 1. Rack Middleware (`Logger::Rails::Middleware`)

The core instrumentation layer. Intercepts all HTTP requests at the Rack level.

**Lifecycle (async two-phase):**

```ruby
# Phase 1: Request arrives → send PENDING entry
entry_id = "rack-#{request_id}"
logger_client.http(method, url, {
  request_headers: filtered_headers(request.headers),
  request_body: capture_body?(request) ? request.body.read : nil,
  request_body_size: request.content_length,
  started_at: Time.now.iso8601(3),
  content_type: request.content_type,
  request_id: request_id,
}, id: entry_id, replace: true)

# Phase 2: Response complete → replace with COMPLETE entry
logger_client.http(method, url, {
  request_headers: filtered_headers(request.headers),
  request_body: capture_body?(request) ? cached_body : nil,
  request_body_size: request.content_length,
  status: response.status,
  status_text: Rack::Utils::HTTP_STATUS_CODES[response.status],
  response_headers: response.headers.to_h,
  response_body: capture_response_body? ? response_body_string : nil,
  response_body_size: response_body_bytes,
  duration_ms: ((Time.now - start_time) * 1000).round,
  ttfb_ms: ((first_byte_time - start_time) * 1000).round,
  started_at: start_time.iso8601(3),
  content_type: response.headers['Content-Type'],
  request_id: request_id,
  is_error: response.status >= 400,
}, id: entry_id, replace: true)
```

**TTFB tracking:** Wrap the response body in a `BodyProxy` that records `first_byte_time` when `#each` is first called.

**Request ID:** Use `ActionDispatch::RequestId` middleware value (`X-Request-Id` header), or generate a UUID fallback.

**Header filtering:**
- Strip sensitive headers by default: `Authorization`, `Cookie`, `Set-Cookie`, `X-API-Key`, `X-Auth-Token`
- Apply `Rails.application.config.filter_parameters` to query strings and body params
- Configurable via `config.sensitive_headers += %w[X-Custom-Secret]`

**Body capture rules:**
- Request body: only if `config.capture_request_body = true` AND content-length < `config.max_body_size` (default: 64KB)
- Response body: only if `config.capture_response_body = true` AND content-length < `config.max_body_size`
- Multipart requests: capture part names and sizes, NOT raw binary. Set `request_body_size` to total.
- Streaming responses: skip body capture, set `response_body_size` from `Content-Length` header if present.

**NestJS equivalent:** NestJS middleware using `@Injectable()` + `NestMiddleware` interface. Request/response interception via `req`/`res` objects. TTFB via response `write` event listener.

### 2. ActiveRecord Integration (`Logger::Rails::ActiveRecordSubscriber`)

Subscribe to `ActiveSupport::Notifications` for `sql.active_record` events.

**Mapping to Logger:**

```ruby
# Each SQL query → a log entry with the http_request parent's request_id
ActiveSupport::Notifications.subscribe('sql.active_record') do |event|
  next if event.payload[:name] == 'SCHEMA'  # skip schema queries
  
  logger_client.log(:debug, "SQL: #{event.payload[:sql]}", {
    labels: {
      'sql.name' => event.payload[:name],
      'sql.duration_ms' => event.duration.round(2).to_s,
      'request_id' => Current.request_id,  # correlate with parent HTTP entry
    },
    tag: 'sql',
  })
end
```

**N+1 detection heuristic:** Track query patterns per request via `Current`. If the same normalized SQL pattern (replace literals with `?`) appears > N times (configurable, default: 5) in a single request, emit a warning-severity entry:

```ruby
logger_client.log(:warning, "N+1 detected: #{pattern} × #{count}", {
  labels: { 'request_id' => Current.request_id, 'sql.pattern' => pattern },
  tag: 'n+1',
})
```

**NestJS equivalent:** TypeORM/Prisma query logging. TypeORM: `createConnection({ logging: true, logger: new LoggerTypeOrmLogger() })`. Prisma: `$on('query', handler)`.

### 3. ActionView Integration (`Logger::Rails::ActionViewSubscriber`)

Subscribe to `render_template.action_view` and `render_partial.action_view`.

```ruby
ActiveSupport::Notifications.subscribe('render_template.action_view') do |event|
  logger_client.log(:debug, "View: #{event.payload[:identifier]}", {
    labels: {
      'view.layout' => event.payload[:layout]&.to_s,
      'view.duration_ms' => event.duration.round(2).to_s,
      'request_id' => Current.request_id,
    },
    tag: 'view',
  })
end
```

**NestJS equivalent:** Handlebars/EJS/Pug render timing via custom `Interceptor` wrapping `res.render()`.

### 4. ActionMailer Integration (`Logger::Rails::ActionMailerSubscriber`)

Subscribe to `deliver.action_mailer`.

```ruby
ActiveSupport::Notifications.subscribe('deliver.action_mailer') do |event|
  logger_client.log(:info, "Mail: #{event.payload[:mailer]}##{event.payload[:action]}", {
    labels: {
      'mail.to' => Array(event.payload[:to]).join(', '),
      'mail.subject' => event.payload[:subject],
      'mail.duration_ms' => event.duration.round(2).to_s,
      'request_id' => Current.request_id,
    },
    tag: 'mail',
  })
end
```

**NestJS equivalent:** `@nestjs/mailer` module instrumentation via custom `MailerService` wrapper.

### 5. ActiveJob Integration (`Logger::Rails::ActiveJobSubscriber`)

Subscribe to `perform.active_job`.

```ruby
ActiveSupport::Notifications.subscribe('perform.active_job') do |event|
  job = event.payload[:job]
  logger_client.log(
    event.payload[:exception] ? :error : :info,
    "Job: #{job.class.name}",
    {
      labels: {
        'job.queue' => job.queue_name,
        'job.id' => job.job_id,
        'job.duration_ms' => event.duration.round(2).to_s,
        'job.attempts' => job.executions.to_s,
        'request_id' => job.provider_job_id,  # or custom metadata
      },
      tag: 'job',
    },
  )
end
```

**NestJS equivalent:** Bull queue event listeners via `@OnQueueCompleted()`, `@OnQueueFailed()` decorators.

### 6. Configuration

```ruby
# config/initializers/logger.rb
Logger::Rails.configure do |config|
  # Connection
  config.server_url = ENV.fetch('LOGGER_URL', 'http://localhost:8080')
  config.app_name = 'my-rails-app'
  config.environment = Rails.env
  
  # Body capture
  config.capture_request_body = true         # default: false
  config.capture_response_body = false       # default: false
  config.max_body_size = 64.kilobytes        # skip bodies larger than this
  
  # Header filtering
  config.sensitive_headers = %w[Authorization Cookie Set-Cookie X-API-Key X-Auth-Token]
  config.filter_params = Rails.application.config.filter_parameters
  
  # Feature toggles
  config.instrument_active_record = true     # default: true
  config.instrument_action_view = true       # default: true
  config.instrument_action_mailer = true     # default: true
  config.instrument_active_job = true        # default: true
  config.detect_n_plus_one = true            # default: true
  config.n_plus_one_threshold = 5            # queries before warning
  
  # Transport
  config.async = true                        # use background thread for sends
  config.batch_size = 50                     # entries per batch
  config.flush_interval_ms = 500             # max wait before flush
  config.retry_on_failure = true             # retry failed sends
  config.max_retries = 3
  
  # Filtering
  config.ignore_paths = %w[/health /ping /assets]  # don't instrument these
  config.ignore_methods = %w[]               # e.g., %w[OPTIONS HEAD]
  
  # Lifecycle
  config.enabled = Rails.env.development?    # only in dev by default
end
```

**NestJS equivalent (`@logger/nestjs`):**

```typescript
// app.module.ts
@Module({
  imports: [
    LoggerModule.forRoot({
      serverUrl: process.env.LOGGER_URL ?? 'http://localhost:8080',
      appName: 'my-nestjs-app',
      captureRequestBody: true,
      captureResponseBody: false,
      maxBodySize: 65536,
      sensitiveHeaders: ['authorization', 'cookie', 'set-cookie'],
      ignorePaths: ['/health', '/ping'],
      async: true,
      batchSize: 50,
    }),
  ],
})
export class AppModule {}
```

### 7. Wire Protocol Mapping

| Rails Concept | Logger Field | Notes |
|---------------|-------------|-------|
| `request.method` | `method` | Uppercase string |
| `request.original_url` | `url` | Full URL including query string |
| `request.headers` (filtered) | `request_headers` | After sensitive header stripping |
| `request.body.read` | `request_body` | Only if configured + within size limit |
| `request.content_length` | `request_body_size` | Always available |
| `response.status` | `status` | Integer |
| `Rack::Utils::HTTP_STATUS_CODES[status]` | `status_text` | Human-readable status |
| `response.headers` | `response_headers` | Hash |
| Response body string | `response_body` | Only if configured + within size limit |
| Response body bytes | `response_body_size` | From Content-Length or body.bytesize |
| `Time.now.iso8601(3)` | `started_at` | Millisecond precision |
| `(end - start) * 1000` | `duration_ms` | Total request time |
| `(first_byte - start) * 1000` | `ttfb_ms` | Time to first response byte |
| `ActionDispatch::RequestId` | `request_id` | X-Request-Id header value |
| `response.headers['Content-Type']` | `content_type` | Response content type |
| `status >= 400` | `is_error` | Boolean |

### 8. Transport Layer

The gem needs an HTTP client to send entries to Logger server. Design decisions:

**Option A: Bundled HTTP client (net/http)**
- Pro: Zero dependencies
- Con: No connection pooling, blocking unless threaded

**Option B: Faraday adapter**
- Pro: Configurable backends, middleware ecosystem
- Con: Heavy dependency for a dev tool

**Recommendation: net/http with a background thread + queue.** Keep it simple. This is a dev tool, not production infrastructure. Use a `SizedQueue` (max 1000 entries) with a single background `Thread` that drains and POSTs batches. Drop entries silently on queue overflow (this is logging, not critical data).

```ruby
# Internal transport (not user-facing)
class Logger::Rails::Transport
  BATCH_SIZE = 50
  FLUSH_INTERVAL = 0.5  # seconds
  
  def initialize(server_url)
    @queue = SizedQueue.new(1000)
    @thread = Thread.new { drain_loop }
  end
  
  def enqueue(entry)
    @queue.push(entry, true) rescue nil  # non-blocking, drop on full
  end
  
  private
  
  def drain_loop
    loop do
      batch = []
      deadline = Time.now + FLUSH_INTERVAL
      while batch.size < BATCH_SIZE && Time.now < deadline
        entry = @queue.pop(true) rescue nil
        batch << entry if entry
        sleep(0.01) if batch.empty?
      end
      send_batch(batch) unless batch.empty?
    end
  end
  
  def send_batch(batch)
    uri = URI("#{@server_url}/api/v2/events")
    Net::HTTP.start(uri.host, uri.port) do |http|
      batch.each do |entry|
        req = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
        req.body = JSON.generate(entry)
        http.request(req)
      end
    end
  rescue StandardError => e
    # Silently drop — this is a dev tool, not a production pipeline
    Rails.logger.debug { "[logger-rails] Send failed: #{e.message}" } if defined?(Rails)
  end
end
```

### 9. Railtie + Engine

Auto-install via Rails engine:

```ruby
# lib/logger/rails/railtie.rb
module Logger
  module Rails
    class Railtie < ::Rails::Railtie
      initializer 'logger_rails.middleware' do |app|
        if Logger::Rails.config.enabled
          app.middleware.insert_after ActionDispatch::RequestId, Logger::Rails::Middleware
        end
      end
      
      initializer 'logger_rails.subscribers' do
        ActiveSupport.on_load(:active_record) do
          Logger::Rails::ActiveRecordSubscriber.attach if Logger::Rails.config.instrument_active_record
        end
        
        ActiveSupport.on_load(:action_view) do
          Logger::Rails::ActionViewSubscriber.attach if Logger::Rails.config.instrument_action_view
        end
        
        ActiveSupport.on_load(:action_mailer) do
          Logger::Rails::ActionMailerSubscriber.attach if Logger::Rails.config.instrument_action_mailer
        end
        
        ActiveSupport.on_load(:active_job) do
          Logger::Rails::ActiveJobSubscriber.attach if Logger::Rails.config.instrument_active_job
        end
      end
      
      config.after_initialize do
        Logger::Rails::Transport.instance.start if Logger::Rails.config.enabled
      end
    end
  end
end
```

### 10. Gem Structure

```
logger-rails/
├── lib/
│   └── logger/
│       └── rails/
│           ├── version.rb
│           ├── configuration.rb        # Config DSL
│           ├── railtie.rb              # Auto-install
│           ├── middleware.rb           # Rack middleware (core)
│           ├── body_proxy.rb          # TTFB-tracking response body wrapper
│           ├── header_filter.rb       # Sensitive header stripping
│           ├── body_capture.rb        # Body capture + size tracking
│           ├── entry_builder.rb       # Build Logger HTTP entries from Rack env
│           ├── transport.rb           # Background thread + net/http sender
│           ├── current.rb             # CurrentAttributes for request context
│           ├── subscribers/
│           │   ├── active_record.rb   # sql.active_record
│           │   ├── action_view.rb     # render_template/render_partial
│           │   ├── action_mailer.rb   # deliver.action_mailer
│           │   └── active_job.rb      # perform.active_job
│           └── n_plus_one_detector.rb # Per-request SQL pattern tracking
├── spec/
│   ├── spec_helper.rb
│   ├── middleware_spec.rb
│   ├── body_proxy_spec.rb
│   ├── header_filter_spec.rb
│   ├── entry_builder_spec.rb
│   ├── transport_spec.rb
│   ├── n_plus_one_detector_spec.rb
│   └── subscribers/
│       ├── active_record_spec.rb
│       ├── action_view_spec.rb
│       ├── action_mailer_spec.rb
│       └── active_job_spec.rb
├── logger-rails.gemspec
├── Gemfile
├── Rakefile
└── README.md
```

### 11. Testing Strategy

**Unit tests (RSpec):**

```ruby
# spec/middleware_spec.rb
RSpec.describe Logger::Rails::Middleware do
  let(:app) { ->(env) { [200, { 'Content-Type' => 'application/json' }, ['{"ok":true}']] } }
  let(:middleware) { described_class.new(app) }
  let(:transport) { instance_double(Logger::Rails::Transport) }
  
  before { allow(Logger::Rails::Transport).to receive(:instance).and_return(transport) }
  
  it 'sends a PENDING entry then a COMPLETE entry' do
    expect(transport).to receive(:enqueue).twice
    middleware.call(Rack::MockRequest.env_for('/api/users', method: 'GET'))
  end
  
  it 'captures status and duration in the COMPLETE entry' do
    entries = []
    allow(transport).to receive(:enqueue) { |e| entries << e }
    middleware.call(Rack::MockRequest.env_for('/api/users'))
    complete = entries.last
    expect(complete.dig(:widget, :status)).to eq(200)
    expect(complete.dig(:widget, :duration_ms)).to be_a(Numeric)
  end
  
  it 'sets is_error for 5xx responses' do
    error_app = ->(env) { [500, {}, ['error']] }
    error_mw = described_class.new(error_app)
    entries = []
    allow(transport).to receive(:enqueue) { |e| entries << e }
    error_mw.call(Rack::MockRequest.env_for('/api/fail'))
    expect(entries.last.dig(:widget, :is_error)).to be true
  end
  
  it 'skips ignored paths' do
    Logger::Rails.config.ignore_paths = %w[/health]
    expect(transport).not_to receive(:enqueue)
    middleware.call(Rack::MockRequest.env_for('/health'))
  end
end

# spec/header_filter_spec.rb
RSpec.describe Logger::Rails::HeaderFilter do
  it 'strips Authorization header' do
    headers = { 'Authorization' => 'Bearer secret', 'Accept' => 'application/json' }
    filtered = described_class.filter(headers)
    expect(filtered).not_to have_key('Authorization')
    expect(filtered['Accept']).to eq('application/json')
  end
end

# spec/n_plus_one_detector_spec.rb
RSpec.describe Logger::Rails::NPlusOneDetector do
  it 'detects repeated SQL patterns' do
    detector = described_class.new(threshold: 3)
    5.times { detector.record('SELECT * FROM users WHERE id = ?') }
    expect(detector.violations).to include('SELECT * FROM users WHERE id = ?')
  end
end
```

**Integration test with a dummy Rails app:**

```ruby
# spec/integration/rails_app_spec.rb
RSpec.describe 'Full Rails integration' do
  let(:app) { DummyRailsApp::Application }
  
  it 'instruments a request end-to-end' do
    # Uses a recorded/mocked Logger server to verify the full entry structure
    get '/api/test'
    expect(recorded_entries.last.dig(:widget, :type)).to eq('http_request')
    expect(recorded_entries.last.dig(:widget, :method)).to eq('GET')
  end
end
```

### 12. Edge Cases

| Case | Handling |
|------|----------|
| Request body is a file upload (multipart) | Capture part names/sizes, NOT binary content. Set `request_body_size`. |
| Response is Server-Sent Events (streaming) | Skip body capture. Set TTFB from first chunk. `duration_ms` = time until stream closes. |
| WebSocket upgrade (101) | Capture the upgrade request. Status 101 triggers Logger's "UPGRADE" badge. |
| Request body already read by another middleware | Use `ActionDispatch::Request` rewindable body. Call `request.body.rewind` after reading. |
| Exception in controller (no response rendered) | Catch in middleware, set `is_error: true`, `status: 500`, capture exception message as `response_body`. |
| Timeout (middleware hangs) | Background thread has its own timeout. Entry stays PENDING in Logger UI. |
| Config says `enabled = false` | Middleware is a no-op passthrough. Zero overhead. |
| `server_url` is unreachable | Transport silently drops entries. Logs once to `Rails.logger.debug`. |
| Thread-safety for `Current` | Use `ActiveSupport::CurrentAttributes` — per-request, thread-safe by design. |
| JSON serialization failure | Rescue `JSON::GeneratorError`, drop the entry, log warning. |
| Large batch payload | Chunk at `batch_size`. Each HTTP POST is a single entry (Logger API is per-entry, not batch). |

### 13. Dependencies

**Runtime:**
- `rails` (>= 6.1) — for Railtie, ActiveSupport, CurrentAttributes
- `rack` (bundled with Rails) — for middleware interface
- No additional gems

**Development:**
- `rspec-rails`
- `webmock` — mock Logger server HTTP calls
- `rack-test` — Rack-level testing

### 14. Release Plan

1. Create gem skeleton with `bundle gem logger-rails`
2. Implement configuration + transport (testable in isolation)
3. Implement Rack middleware (core feature; test with Rack::MockRequest)
4. Implement header filtering + body capture (extract from middleware)
5. Implement ActiveRecord subscriber + N+1 detection
6. Implement remaining subscribers (ActionView, ActionMailer, ActiveJob)
7. Add Railtie for auto-install
8. Integration test with a dummy Rails app
9. Write README with setup instructions + screenshot of Logger viewer showing Rails requests
10. Publish to RubyGems

### 15. README Snippet (for the gem)

````markdown
# logger-rails

Automatic Rails instrumentation for [Logger](https://github.com/your-org/logger), a real-time structured log viewer.

## Quick Start

```ruby
# Gemfile
gem 'logger-rails', group: :development

# config/initializers/logger.rb
Logger::Rails.configure do |config|
  config.server_url = 'http://localhost:8080'
  config.app_name = 'my-app'
  config.capture_request_body = true
end
```

That's it. Start your Rails server, open the Logger viewer, and see every HTTP request with status, timing, headers, and body — live.

## What You Get

- **HTTP request lifecycle** — See requests appear as PENDING, then update to COMPLETE with status + timing
- **TTFB tracking** — Know if your server is slow to respond or just sending a large body
- **SQL query correlation** — Every SQL query linked to its parent HTTP request via request_id
- **N+1 detection** — Automatic warnings when the same query pattern repeats > 5 times in one request
- **View render timing** — See which templates and partials are slow
- **Sensitive header masking** — Authorization headers stripped by default
- **Zero-config** — Works out of the box in `development` environment
```
````
