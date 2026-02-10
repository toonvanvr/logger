// session-message.ts — Session lifecycle messages
export {
    ApplicationInfo,
    SessionMessage,
    type ApplicationInfo as ApplicationInfoType
} from './session-message.js'

// event-message.ts — Structured log events
export {
    EventMessage,
    ExceptionData,
    IconRef,
    Severity,
} from './event-message.js'

// data-message.ts — Key-value state updates
export {
    DataMessage,
    DisplayLocation,
    WidgetConfig,
} from './data-message.js'

// widget.ts — Rich widget payload types
export {
    TreeNodeSchema,
    WidgetPayload,
    type TreeNode
} from './widget.js'

// stored-entry.ts — Wire protocol (source of truth)
export {
    EntryKind,
    StoredEntry
} from './stored-entry.js'

// server-broadcast.ts — Server → Viewer broadcast messages
export {
    DataState,
    ServerBroadcast,
    SessionInfo
} from './server-broadcast.js'

// viewer-command.ts — Viewer → Server command messages
export {
    ViewerCommand
} from './viewer-command.js'

// constants.ts — Shared size limits, network defaults, error codes
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

