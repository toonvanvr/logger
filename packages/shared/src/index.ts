// ─── Session ─────────────────────────────────────────────────────────
export {
    ApplicationInfo,
    ApplicationInfoSchema,
    SessionMessage,
    type ApplicationInfo as ApplicationInfoType
} from './session-message.js'

// ─── Events ──────────────────────────────────────────────────────────
export {
    EventMessage,
    ExceptionData,
    ExceptionDataSchema,
    IconRef,
    IconRefSchema,
    Severity,
    SeveritySchema
} from './event-message.js'

// ─── Data ────────────────────────────────────────────────────────────
export {
    DataMessage,
    DisplayLocation,
    DisplayLocationSchema,
    WidgetConfig,
    WidgetConfigSchema
} from './data-message.js'

// ─── Widgets ─────────────────────────────────────────────────────────
export {
    TreeNodeSchema,
    WidgetPayload,
    type TreeNode
} from './widget.js'

// ─── Stored Entry ────────────────────────────────────────────────────
export {
    EntryKind,
    StoredEntry
} from './stored-entry.js'

// ─── Server Broadcast ───────────────────────────────────────────────
export {
    DataState,
    ServerBroadcast,
    SessionInfo
} from './server-broadcast.js'

// ─── Viewer Command ──────────────────────────────────────────────────
export {
    ViewerCommand
} from './viewer-command.js'

// ─── Constants ───────────────────────────────────────────────────────
export {
    DEFAULT_DATA_URL,
    DEFAULT_EVENTS_URL,
    DEFAULT_HOST,
    DEFAULT_SERVER_PORT,
    DEFAULT_SESSION_URL,
    DEFAULT_TCP_PORT,
    DEFAULT_UDP_PORT,
    DEFAULT_WS_URL,
    ERROR_CODES,
    MAX_BATCH_SIZE,
    MAX_BINARY_SIZE,
    MAX_IMAGE_SIZE,
    MAX_JSON_SIZE,
    MAX_SESSION_ID_LENGTH,
    MAX_TAGS,
    MAX_TEXT_SIZE,
    RING_BUFFER_DEFAULT_SIZE
} from './constants.js'
export type { ErrorCode } from './constants.js'

