// HOW TO ADD A SCHEMA:
// 1. Create .ts file with Zod schema + inferred type export
// 2. Add re-exports below in the appropriate section
// 3. Update protocol conformance fixtures if any

export {
    ApplicationInfo,
    SessionMessage,
    type ApplicationInfo as ApplicationInfoType
} from './session-message.js'

export {
    EventMessage,
    ExceptionData,
    IconRef,
    Severity,
    SourceLocation,
    StackFrame,
} from './event-message.js'

export {
    DataMessage,
    DisplayLocation,
    WidgetConfig,
} from './data-message.js'

export {
    TreeNodeSchema,
    WidgetPayload,
    type TreeNode
} from './widget.js'

export {
    EntryKind,
    StoredEntry
} from './stored-entry.js'

export {
    DataState,
    ServerBroadcast,
    SessionInfo
} from './server-broadcast.js'

export {
    ViewerCommand
} from './viewer-command.js'

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

