// ─── Log Entry & Core Types ──────────────────────────────────────────
export {
    ApplicationInfo, ExceptionData, GroupAction, IconRef,
    ImageData, LogBatch, LogEntry, LogType, RpcDirection, SessionAction, Severity, SourceLocation,
    StackFrame
} from './log-entry';

// ─── Server Messages ─────────────────────────────────────────────────
export {
    ServerMessage, ServerMessageType,
    SessionInfo
} from './server-message';

// ─── Viewer Messages ─────────────────────────────────────────────────
export {
    ViewerMessage, ViewerMessageType
} from './viewer-message';

// ─── Custom Renderers ────────────────────────────────────────────────
export {
    ChartRendererData, CustomRendererData, DiffRendererData, KvRendererData, ProgressRendererData, TableRendererData, TimelineRendererData, TreeNodeSchema, TreeRendererData
} from './custom-renderers';
export type { TreeNode } from './custom-renderers';

// ─── Constants ───────────────────────────────────────────────────────
export {
    DEFAULT_HOST, DEFAULT_HTTP_URL, DEFAULT_SERVER_PORT, DEFAULT_TCP_PORT, DEFAULT_UDP_PORT, DEFAULT_WS_URL, ERROR_CODES, MAX_BATCH_SIZE, MAX_BINARY_SIZE,
    MAX_IMAGE_SIZE, MAX_JSON_SIZE, MAX_SESSION_ID_LENGTH, MAX_TAGS, MAX_TEXT_SIZE, RING_BUFFER_DEFAULT_SIZE
} from './constants';
export type { ErrorCode } from './constants';

