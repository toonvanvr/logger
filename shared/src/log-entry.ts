import { z } from 'zod';

// ─── Enums ───────────────────────────────────────────────────────────

export const Severity = z.enum([
  'debug',
  'info',
  'warning',
  'error',
  'critical',
]);
export type Severity = z.infer<typeof Severity>;

export const LogType = z.enum([
  'text',
  'json',
  'html',
  'binary',
  'image',
  'state',
  'group',
  'rpc',
  'session',
  'custom',
]);
export type LogType = z.infer<typeof LogType>;

export const GroupAction = z.enum(['open', 'close']);
export type GroupAction = z.infer<typeof GroupAction>;

export const SessionAction = z.enum(['start', 'end', 'heartbeat']);
export type SessionAction = z.infer<typeof SessionAction>;

export const RpcDirection = z.enum(['request', 'response', 'error']);
export type RpcDirection = z.infer<typeof RpcDirection>;

// ─── Sub-schemas ─────────────────────────────────────────────────────

export const SourceLocation = z.object({
  /** File path or URI */
  uri: z.string(),
  /** 1-based line number */
  line: z.number().int().optional(),
  /** 1-based column number */
  column: z.number().int().optional(),
  /** Function/method name */
  symbol: z.string().optional(),
});
export type SourceLocation = z.infer<typeof SourceLocation>;

export const StackFrame = z.object({
  location: SourceLocation,
  /** true for node_modules, dart:, etc. */
  isVendor: z.boolean().optional(),
  /** Original unparsed frame string */
  raw: z.string().optional(),
});
export type StackFrame = z.infer<typeof StackFrame>;

export const ExceptionData: z.ZodType<{
  type?: string;
  message: string;
  stackTrace?: Array<{ location: { uri: string; line?: number; column?: number; symbol?: string }; isVendor?: boolean; raw?: string }>;
  cause?: unknown;
}> = z.object({
  /** e.g., "TypeError", "FormatException" */
  type: z.string().optional(),
  message: z.string(),
  stackTrace: z.array(StackFrame).optional(),
  /** Chained exception cause */
  cause: z.lazy(() => ExceptionData).optional(),
});
export type ExceptionData = z.infer<typeof ExceptionData>;

export const ApplicationInfo = z.object({
  /** e.g., "my-api-server" */
  name: z.string(),
  /** e.g., "1.2.3" */
  version: z.string().optional(),
  /** e.g., "development" */
  environment: z.string().optional(),
});
export type ApplicationInfo = z.infer<typeof ApplicationInfo>;

export const IconRef = z.object({
  /** Iconify ID, e.g., "mdi:home" */
  icon: z.string(),
  /** Hex color override, e.g., "#FF0000" */
  color: z.string().optional(),
  /** Size in dp, default 14 */
  size: z.number().optional(),
});
export type IconRef = z.infer<typeof IconRef>;

export const ImageData = z
  .object({
    /** Base64-encoded image data (for inline transport) */
    data: z.string().optional(),
    /** Reference ID returned by POST /api/v1/upload */
    ref: z.string().optional(),
    /** MIME type, e.g., "image/png" */
    mimeType: z.string().optional(),
    /** Display label */
    label: z.string().optional(),
    /** Width in pixels (metadata) */
    width: z.number().int().optional(),
    /** Height in pixels (metadata) */
    height: z.number().int().optional(),
  })
  .refine((d) => d.data !== undefined || d.ref !== undefined, {
    message: 'ImageData requires either data (base64) or ref (upload reference)',
  });
export type ImageData = z.infer<typeof ImageData>;

// ─── LogEntry (the unified protocol message) ────────────────────────

export const LogEntry = z.object({
  // ── Required fields ──
  /** Client-assigned ID. String to allow both UUID and custom string IDs. */
  id: z.string(),
  /** ISO 8601 timestamp with millisecond precision */
  timestamp: z.string().datetime({ offset: true }),
  /** Session ID — groups logs from a single application run */
  session_id: z.string(),
  /** Log severity level */
  severity: Severity,
  /** Discriminator for log entry type */
  type: LogType,

  // ── Application metadata (optional) ──
  application: ApplicationInfo.optional(),

  // ── Section targeting ──
  /** Which UI section this log belongs to. Defaults to "events" */
  section: z.string().optional(),

  // ── Content fields (type-dependent) ──
  /** For type: "text" — plain text content */
  text: z.string().optional(),
  /** For type: "json" — arbitrary JSON payload */
  json: z.unknown().optional(),
  /** For type: "html" — HTML string content */
  html: z.string().optional(),
  /** For type: "binary" — base64-encoded binary data */
  binary: z.string().optional(),
  /** For type: "image" — image data or reference */
  image: ImageData.optional(),

  // ── Exception / stack trace (can accompany any type) ──
  exception: ExceptionData.optional(),

  // ── Icon reference ──
  icon: IconRef.optional(),

  // ── Group operations ──
  /** Group ID. All entries in a group share this. */
  group_id: z.string().optional(),
  /** What action to perform on the group */
  group_action: GroupAction.optional(),
  /** Group display label (used with group_action: "open") */
  group_label: z.string().optional(),
  /** Whether the group starts collapsed in the viewer */
  group_collapsed: z.boolean().optional(),

  // ── Sticky pinning ──
  /** When true, this entry (or group) pins to the top of the viewport when scrolled past */
  sticky: z.boolean().optional(),

  // ── State operations (type: "state") ──
  /** State key for upsert. Unique per session. */
  state_key: z.string().optional(),
  /** State value. null = delete the key. */
  state_value: z.unknown().optional(),

  // ── Session control (type: "session") ──
  session_action: SessionAction.optional(),

  // ── Ordering hints ──
  /** Insert this log visually after the entry with this ID */
  after_id: z.string().optional(),
  /** Insert this log visually before the entry with this ID */
  before_id: z.string().optional(),

  // ── 2-Way RPC (type: "rpc") ──
  /** Unique RPC call ID */
  rpc_id: z.string().uuid().optional(),
  /** Direction of the RPC message */
  rpc_direction: RpcDirection.optional(),
  /** RPC method name */
  rpc_method: z.string().optional(),
  /** RPC arguments (request direction) */
  rpc_args: z.unknown().optional(),
  /** RPC response data (response direction) */
  rpc_response: z.unknown().optional(),
  /** RPC error message (error direction) */
  rpc_error: z.string().optional(),

  // ── Request timing metadata ──
  /** When the log was originally generated */
  generated_at: z.string().datetime({ offset: true }).optional(),
  /** When the log was sent over the wire */
  sent_at: z.string().datetime({ offset: true }).optional(),

  // ── Tags ──
  /** Arbitrary key-value tags for filtering/searching */
  tags: z.record(z.string(), z.string()).optional(),

  // ── Patch 3: In-place entry updates ──
  /** When true + id matches existing entry, upsert (replace in-place) */
  replace: z.boolean().optional(),

  // ── Custom type fields ──
  /** Custom type discriminator (when type: "custom") */
  custom_type: z.string().optional(),
  /** Custom renderer data (when type: "custom") */
  custom_data: z.unknown().optional(),
});
export type LogEntry = z.infer<typeof LogEntry>;

// ─── Batch Wrapper ───────────────────────────────────────────────────

export const LogBatch = z.object({
  /** Array of log entries */
  entries: z.array(LogEntry).min(1).max(1000),
});
export type LogBatch = z.infer<typeof LogBatch>;
