# Widget Suggestion Catalog

**Date**: 2026-02-11 | **Scope**: 100 widget ideas across 12 development domains | **Confidence**: HIGH

> Excludes existing types: http_request, chart, progress, table, kv, diff, tree, timeline, json, html, binary, image.

---

## 100 Widget Ideas (One-Liners)

### Observability & Tracing (1–10)
1. **Span Waterfall** — Distributed trace spans as horizontal bars with timing
2. **Flame Chart Mini** — Collapsed flame graph showing call stack hot paths
3. **Metric Gauge** — Real-time gauge (CPU, memory, disk) with thresholds
4. **Log Pattern Cluster** — Groups similar log messages with occurrence count
5. **Correlation Chain** — Linked trace IDs across services as clickable chain
6. **SLO Budget Burn** — Error budget remaining as depleting bar with burn rate
7. **Histogram Heatmap** — Latency distribution as color-coded time buckets
8. **Alert Card** — Firing alert with severity, expression, and duration badge
9. **Annotation Marker** — Deployment/incident marker spanning the log timeline
10. **Service Map Edge** — Single service-to-service call with latency and error rate

### Database & Storage (11–20)
11. **SQL Query Plan** — EXPLAIN plan as indented nodes with cost/row estimates
12. **Slow Query Card** — Query text + duration + table scans highlighted in red
13. **Connection Pool Gauge** — Active/idle/waiting connections as stacked bar
14. **Transaction Boundary** — BEGIN→COMMIT/ROLLBACK block with nested savepoints
15. **Migration Step** — Migration name + direction (up/down) + duration + status
16. **Redis Command Card** — Command, key pattern, latency, memory impact
17. **Cache Hit/Miss Badge** — Key + hit/miss + age + TTL + size
18. **Replication Lag** — Leader→replica delay as gauge with threshold warning
19. **Index Usage Card** — Index name + table + hit rate + unused-since indicator
20. **Deadlock Graph** — Two transactions with conflicting lock arrows

### API & Networking (21–30)
21. **GraphQL Resolver Map** — Query tree with per-field resolve times
22. **gRPC Call Card** — Service/method, metadata, streaming indicator, status
23. **WebSocket Frame Pair** — Send/receive messages matched with round-trip time
24. **Retry Backoff Curve** — Attempts plotted on exponential curve with outcome
25. **DNS Lookup Chain** — Recursive resolution hops with TTLs per step
26. **TLS Handshake Card** — Cipher suite, cert chain depth, handshake duration
27. **Rate Limit Gauge** — Current rate vs limit with cooldown remaining
28. **Proxy Hop Chain** — Request path through proxy layers with added latency
29. **API Deprecation Notice** — Endpoint + sunset date + replacement link
30. **Content Negotiation** — Accept vs Content-Type resolution with quality weights

### State Machines & Workflows (31–40)
31. **State Machine Transition** — From→To states with trigger event and guard
32. **Circuit Breaker** — Open/half-open/closed state with error % and trip count
33. **Saga Step** — Step name in saga with compensating action on failure
34. **Order Lifecycle** — Order states as horizontal pipeline with current marker
35. **Approval Flow** — Multi-step approval chain with pending/approved/rejected
36. **Job Queue Card** — Job name, priority, attempts, worker, duration
37. **Cron Execution** — Scheduled vs actual time + drift + next run countdown
38. **Workflow DAG Step** — Current node in DAG with completed/pending branches
39. **Lock Acquisition** — Resource + holder + wait time + timeout indicator
40. **Batch Progress** — Items processed/failed/remaining in a batch operation

### Infrastructure & DevOps (41–50)
41. **Container Resources** — CPU/mem/net as triple mini-gauge for one container
42. **K8s Pod Event** — Pod lifecycle phase + condition + restart count
43. **Deployment Rollout** — Replica progress bar (old→new) with canary %
44. **Terraform Plan Delta** — Resources to add/change/destroy as colored counts
45. **CI Pipeline Stage** — Stage boxes with pass/fail/running status and duration
46. **Docker Build Layer** — Layer instruction + cached/rebuilt + size delta
47. **Load Balancer Route** — Request → selected backend + selection algorithm
48. **Certificate Expiry** — Domain + issuer + days remaining with color coding
49. **Cloud Cost Tick** — Estimated cost of this operation in microdollars
50. **Config Drift Alert** — Expected vs actual config value with source

### Security & Auth (51–60)
51. **JWT Decoder** — Header/payload sections decoded with expiry countdown
52. **Permission Check** — Subject + action + resource → allowed/denied with reason
53. **OAuth Flow Step** — Authorization code/token exchange step with redirect
54. **CORS Preflight** — Origin + allowed origins check with pass/fail
55. **CSP Violation** — Violated directive + blocked URI + source file/line
56. **Audit Trail Entry** — Who + what + when + where as structured card
57. **Secret Rotation** — Key name + rotated from/to + next rotation date
58. **IP Reputation Badge** — IP + geo + threat score + blocklist membership
59. **MFA Challenge** — Method (TOTP/WebAuthn/SMS) + status + fallback used
60. **Encryption Envelope** — Algorithm + plaintext→ciphertext size + key ID

### Testing & Quality (61–70)
61. **Test Result Card** — Test name + pass/fail/skip + duration + assertion detail
62. **Test Suite Bar** — Mini green/red/yellow bar with counts and total time
63. **Coverage Delta** — File + before/after % + uncovered line ranges
64. **Flaky Test Tracker** — Test name + failure rate over last N runs as sparkline
65. **Snapshot Diff** — Expected vs received snapshot with inline highlights
66. **Load Test Gauge** — RPS + p50/p95/p99 latencies + error rate in one row
67. **Contract Test** — Provider + consumer + schema compatibility verdict
68. **Mutation Score** — Mutants killed/survived as ratio bar per module
69. **Accessibility Violation** — WCAG rule + element + severity + fix suggestion
70. **Visual Regression** — Thumbnail before/after with pixel diff percentage

### Mobile & Frontend (71–80)
71. **Screen Navigation** — Stack of screens as breadcrumb with transition type
72. **Component Render Count** — Component name + render count + wasted renders
73. **Bundle Size Chunk** — Chunk name + size + gzipped size + % of total
74. **Core Web Vitals** — LCP/FID/CLS as traffic-light badges in one row
75. **Deep Link Route** — URL → resolved screen + extracted parameters
76. **Gesture Event** — Gesture type + coordinates + velocity on mini canvas
77. **Push Notification** — Title + sent→delivered→opened funnel with timestamps
78. **Animation Frame Drop** — Frame budget vs actual with dropped frame count
79. **Responsive Breakpoint** — Viewport width + active breakpoint + layout name
80. **Local Storage Delta** — Key + old→new value + storage quota usage

### Data & ML (81–90)
81. **Training Step** — Epoch + loss/accuracy/lr as inline sparkline trio
82. **Data Validation** — Schema check with per-field pass/fail status row
83. **ETL Stage Card** — Extract→Transform→Load with record counts per stage
84. **Feature Importance** — Ranked horizontal bars with feature names and scores
85. **Confusion Matrix** — Small 2×2 or 3×3 heatmap grid with counts
86. **Model Inference** — Input summary → prediction + confidence as styled card
87. **Anomaly Marker** — Value + expected range + sigma deviation highlighted
88. **A/B Experiment** — Variant allocation + metric + statistical significance
89. **Data Pipeline DAG** — Current stage in ETL DAG with throughput per node
90. **Embedding Distance** — Query vs result + cosine similarity score bar

### IoT & Hardware (91–95)
91. **Sensor Reading** — Value + unit + sparkline + threshold zone coloring
92. **Device State Machine** — State transition with trigger + timestamp
93. **MQTT Message** — Topic + QoS + retain flag + payload preview
94. **Firmware OTA** — Version from→to + download/verify/flash progress phases
95. **GPIO Pin Map** — Pin number + HIGH/LOW state + pull-up/down indicator

### Developer Experience (96–100)
96. **Regex Match** — Pattern + input + highlighted capture groups inline
97. **Dependency Alert** — Package + current vs latest + CVE count badge
98. **Git Commit Card** — Hash + author + message + files changed compact row
99. **Codemod Result** — Files modified/skipped/errored with transform description
100. **Feature Flag Decision** — Flag key + context → evaluated variant with rules

---

## Top 10 — Expanded

### 1. Span Waterfall
Imagine seeing a full distributed trace *right inside your log stream* — no tab-switching to Jaeger, no copy-pasting trace IDs. The Span Waterfall renders each service's span as a proportionally-sized horizontal bar, color-coded by service, with precise timing offsets from the root span. When you expand it, you see the full span tree with metadata, tags, and error markers. This is the single most-requested observability visualization, and having it *inline* with your application logs makes it 10x more useful than any standalone trace viewer.

### 2. SQL Query Plan
Every backend developer has copy-pasted EXPLAIN output into a text editor and squinted at it. The SQL Query Plan widget renders EXPLAIN/ANALYZE results as an indented tree with cost percentages, row count estimates vs actuals, and bright red highlights on sequential scans and high-cost nodes. Collapsed, it shows just "Sequential Scan on users — 842ms, 1.2M rows examined." Expanded, it's a full plan tree you can actually read. This widget alone would make Logger the go-to tool for database debugging.

### 3. State Machine Transition
Whether it's a circuit breaker, order lifecycle, payment flow, or IoT device — state machines are everywhere and nearly invisible in traditional logs. This widget shows a crisp From→To transition with the trigger event, guard condition, and timestamp. Collapsed, it's a single row: `[idle] →triggered→ [processing]`. Expanded, it shows the full state diagram context. Chain multiple transitions together and you get a visual audit trail of exactly how your system evolved. Debugging "how did we get into this state?" becomes trivial.

### 4. Circuit Breaker
Microservice developers live and die by their circuit breakers, yet most only find out they've tripped by noticing cascading failures. This widget shows the current state (CLOSED/OPEN/HALF-OPEN) as a bold colored badge, with error rate %, failure count, and time until next retry probe. When it trips, it's *immediately* visible in the log stream — a bright red OPEN badge that demands attention. One glance replaces minutes of log spelunking.

### 5. JWT Decoder
You've base64-decoded JWTs in the terminal a thousand times. This widget does it inline: collapsed shows the issuer, subject, and a countdown badge for expiry. Expanded reveals the full decoded header and payload with syntax highlighting, the signature algorithm, and a red/green validity indicator. For debugging auth issues — wrong audience, expired tokens, missing claims — this is instant clarity instead of copying tokens to jwt.io.

### 6. Test Result Card
CI logs are walls of text. The Test Result Card extracts signal from noise: a single row showing test name, pass/fail/skip status as a colored badge, duration, and — critically — the *assertion message* on failure, right there in the collapsed row. Expanded, it shows the full stack trace, expected vs actual values, and the test file location. Wire this to your test runner and your log stream becomes a live test dashboard.

### 7. Retry Backoff Curve
When your service retries a failing call, the logs usually show "retry attempt 3 of 5" — but how long did each attempt take? What was the backoff? The Retry Backoff Curve plots all attempts on a mini exponential curve, with the actual delay shown as dots. Successful retries get a green final dot; exhausted retries end in red. At a glance, you see whether your backoff strategy is sane and which attempt finally succeeded.

### 8. Container Resources
Docker logs show what a container *said*, but not how it *felt*. The Container Resources widget shows CPU, memory, and network I/O as three compact gauges in a single row, color-coded by threshold (green→yellow→red). When a service is slow, one glance tells you if it's memory-constrained or CPU-starved. It's the vital signs monitor for your containers, embedded right in the log stream where the symptoms appear.

### 9. GraphQL Resolver Map
GraphQL's blessing and curse: the client asks for exactly what it needs, but N+1 queries hide behind innocent-looking fields. The Resolver Map shows the query structure as an indented tree, with per-field resolve time as colored badges. Slow fields glow red. Collapsed, it shows the operation name and total duration. This is the profiler view that every GraphQL developer has wished existed *inline* with their server logs.

### 10. Feature Flag Decision
"Why did user X see the old UI?" Feature flag debugging is notoriously opaque. This widget shows exactly what happened: the flag key, the evaluation context (user ID, segment, environment), the rule that matched, and the resulting variant — all in one compact card. When a flag evaluates to something unexpected, the reasoning is right there. No more digging through LaunchDarkly's UI to cross-reference with your logs.

---

## Top 3 — Deep Dive

### 1. Span Waterfall

**Vision**: Inline distributed trace visualization that renders OpenTelemetry-compatible span data as a horizontal waterfall chart within the log stream. Developers see the complete request lifecycle — from initial HTTP call through database queries and downstream service calls — without leaving their log viewer.

**Collapsed Row**:
```
 ▸  ⟫ GET /api/orders  ── 4 spans ── 243ms ── order-svc → inventory-svc → pg
```
Shows: expand chevron, root span operation, span count badge, total duration, service chain summary.

**Expanded View**:
- **Waterfall Chart**: Horizontal bars proportional to time, left-aligned to parent span start.
- **Span Detail Panel**: Click a bar → metadata (service, tags, status, events, logs).
- **Critical Path**: Longest chain highlighted with dotted outline.
- **Error Markers**: Failed spans in `error` color with exclamation icon.
- **Timing Axis**: Millisecond ruler at top, total duration at right edge.

**Killer Feature**: Click any span bar to filter the log stream to entries from that service + time window. The log viewer becomes a trace-driven debugger.

**Use Cases**:
1. Debugging slow API responses by seeing which downstream service added latency.
2. Finding N+1 query patterns — 50 tiny DB spans stacked under one service call.
3. Identifying timeout cascades — a child span exceeds parent's deadline.
4. Tracing async workflows — message publish in service A, consume in service B.
5. Correlating errors — a 500 in the gateway traced back to a failed DB query 3 hops deep.

**Integration Points**:
- Accepts `trace_id`/`span_id` from log entry labels for cross-referencing with the stream.
- `duration_ms` and `started_at` align with the time-travel minimap for zoom-to-trace.
- Span services can link to the service map widget if both are present.
- Stacking: use `replace: true` to update a trace as new spans arrive (in-flight → complete).

**Design Sketch**:
```
┌─────────────────────────────────────────────────────┐
│ ▾  ⟫ GET /api/orders  ── 4 spans ── 243ms          │
│                                                     │
│   0ms            100ms           200ms        243ms │
│   ├───────────────┼───────────────┼────────────┤    │
│                                                     │
│   ████████████████████████████████████████████ root  │
│   │ order-svc: GET /api/orders         243ms        │
│   │                                                 │
│   │  ███████████████████░░░░░░░░░░░░░░ child1       │
│   │  │ inventory-svc: CheckStock       142ms        │
│   │  │                                              │
│   │  │  █████████░░░░░░░░░░░░░░░░░░░░░ child2      │
│   │  │  pg: SELECT * FROM stock          67ms       │
│   │  │                                              │
│   │  ██████░░░░░░░░░░░░░░░░░░░░░░░░░░ child3       │
│   │  cache: GET inventory:sku:1234       12ms       │
│                                                     │
│   ⚠ Critical path: root → child1 → child2 (209ms)  │
└─────────────────────────────────────────────────────┘
```
Bar colors: one per service (derived from service name hash). Error spans use `syntaxError` fill. Timing axis uses `fgMuted`. Labels use `logMeta` style. Bar height: 20px, gap: 4px. Total height adapts to span count (max ~300px with scroll).

---

### 2. SQL Query Plan

**Vision**: Renders database EXPLAIN/ANALYZE output as a visual tree with cost annotations, making query performance analysis instant and inline. No more copy-pasting to pganalyze or reading raw EXPLAIN text.

**Collapsed Row**:
```
 ▸  ⌗ SELECT orders  ── Seq Scan ⚠ ── 842ms ── 1.2M rows
```
Shows: expand chevron, query summary, worst node type as warning badge, execution time, row count.

**Expanded View**:
- **Plan Tree**: Indented nodes — one per plan operation (Seq Scan, Index Scan, Hash Join, etc.).
- **Cost Bars**: Each node has a proportional width bar showing % of total cost.
- **Row Estimates**: Estimated vs actual rows — large mismatches flagged in `warning` color.
- **Node Badges**: Node type as colored pill (green=Index Scan, yellow=Seq Scan, red=Nested Loop on large tables).
- **Query Text**: Syntax-highlighted SQL at the bottom, truncated with expand.
- **Suggestions Strip**: Auto-generated hints ("Add index on orders.user_id", "Consider LIMIT").

**Killer Feature**: Cost bars give an instant "where does the time go?" answer. A 95%-wide red bar on a Seq Scan is impossible to miss — you *see* the bottleneck, not read about it.

**Use Cases**:
1. Catching accidental sequential scans on million-row tables during development.
2. Comparing query plans before/after adding an index (using stacking with `replace: true`).
3. Spotting row estimate mismatches that indicate stale statistics.
4. Debugging ORM-generated queries by seeing the actual plan alongside the ORM call.
5. Monitoring query plan regression after schema migrations.

**Integration Points**:
- Pairs with the `table` widget for result set preview alongside the plan.
- `duration_ms` feeds into the time-travel minimap for slow-query time ranges.
- Stack with initial EXPLAIN then EXPLAIN ANALYZE to compare estimated vs actual.
- Labels: `db.system=postgresql`, `db.name=mydb` for filter integration.

**Design Sketch**:
```
┌─────────────────────────────────────────────────────┐
│ ▾  ⌗ SELECT orders  ── Seq Scan ⚠ ── 842ms         │
│                                                     │
│   Hash Join  (cost=1245..3892)            ████ 100% │
│   ├─ Seq Scan on orders  ⚠               ███░  87% │
│   │  rows: estimated 1000  actual 1.2M  ⚠ 1200×    │
│   │  filter: created_at > '2026-01-01'              │
│   │                                                 │
│   └─ Index Scan on users                  █░░░  13% │
│      using users_pkey                               │
│      rows: estimated 50  actual 48    ✓             │
│                                                     │
│   ┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄  │
│   💡 Add index: CREATE INDEX idx_orders_created     │
│      ON orders (created_at);                        │
│                                                     │
│   SELECT o.*, u.name FROM orders o                  │
│   JOIN users u ON o.user_id = u.id                  │
│   WHERE o.created_at > '2026-01-01';               │
└─────────────────────────────────────────────────────┘
```
Tree indentation: 16px per level. Cost bars: inline right-aligned, `syntaxNumber` fill, `bgSurface` track. Warning badges: `warning` color. Row mismatch >10× shown in `error` color. Query text in `logBody` with `syntaxKey`/`syntaxString` highlights.

---

### 3. State Machine Transition

**Vision**: A universal state machine visualizer that renders any state transition as a compact, beautiful card — applicable to circuit breakers, order flows, payment states, IoT devices, auth sessions, and any domain with discrete states. Chains of transitions in the log stream form a visual audit trail.

**Collapsed Row**:
```
 ▸  ◉ PaymentFlow  [authorized] →capture→ [captured]  12ms
```
Shows: expand chevron, state machine name, from-state in muted box, trigger arrow, to-state in accent box, transition duration.

**Expanded View**:
- **Transition Detail**: From state, to state, trigger event, guard condition, action executed.
- **State Context**: Key-value metadata attached to the new state (e.g., `amount: $49.99`).
- **Mini State Diagram**: ASCII/simple visual showing all known states with current state highlighted.
- **History Strip**: Last N transitions from this machine as a compact dot chain.
- **Side Effects**: Actions triggered by this transition (e.g., "Sent webhook", "Enqueued job").

**Killer Feature**: The history strip. When you see 5 state transitions in a row in the log stream, each one shows a dot chain of all prior states — so you can instantly see the *full journey* from any single entry, not just the current transition. "How did we get here?" answered at a glance.

**Use Cases**:
1. Debugging why a circuit breaker tripped — see the error count climb across transitions.
2. Auditing order lifecycle — created→paid→shipped→delivered with timestamps at each step.
3. IoT device debugging — device cycling between online/offline states with trigger events.
4. Payment flow — auth→capture→settle or auth→void with compensating actions visible.
5. Auth session lifecycle — login→active→refresh→expired with token metadata at each state.

**Integration Points**:
- Uses `replace: true` + stable entry ID per machine instance → stacking shows full lifecycle.
- State machine name maps to a filterable label for "show me all transitions for PaymentFlow X".
- Side effects can cross-reference other log entries via correlation ID.
- Pairs with the `kv` widget for the state context metadata.

**Design Sketch**:
```
┌─────────────────────────────────────────────────────┐
│ ▾  ◉ PaymentFlow  [authorized] →capture→ [captured] │
│                                                     │
│   Trigger:  capture_payment                         │
│   Guard:    amount ≤ authorized_amount              │
│   Action:   ChargeGateway → success                 │
│   Duration: 12ms                                    │
│                                                     │
│   Context:                                          │
│     amount ........... $49.99                        │
│     gateway_ref ...... ch_1abc234                    │
│     captured_at ...... 2026-02-11T14:32:01Z         │
│                                                     │
│   States:                                           │
│     ○ created → ● authorized → ◉ captured → ○ settled │
│                                                     │
│   History: ○──○──●──◉                               │
│            │  │  │  └ captured  (now)                │
│            │  │  └── authorized (2s ago)             │
│            │  └───── created    (5s ago)             │
│            └──────── initialized                    │
│                                                     │
│   Side Effects:                                     │
│     → Webhook: payment.captured sent to /hooks      │
│     → Job: GenerateInvoice enqueued                 │
└─────────────────────────────────────────────────────┘
```
State dots: `○` = visited, `●` = previous, `◉` = current. Current state uses `syntaxKey` color. Trigger/guard/action use `logMeta` style. History lines use `borderSubtle`. Context keys in `syntaxKey`, values in `fgPrimary`. Side effects use `fgSecondary` with `→` prefix.
