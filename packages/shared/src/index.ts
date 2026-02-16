// HOW TO ADD A SCHEMA:
// 1. Create .ts file with Zod schema + inferred type export
// 2. Add re-exports below in the appropriate section
// 3. Update protocol conformance fixtures if any

export {
    ApplicationInfo,
    SessionMessage,
    type ApplicationInfo as ApplicationInfoType
} from './session-message'

export {
    EventMessage,
    ExceptionData,
    IconRef,
    Severity,
    SourceLocation,
    StackFrame,
    type SeverityLevel
} from './event-message'

export {
    DataMessage,
    DisplayLocation,
    WidgetConfig
} from './data-message'

export {
    TreeNodeSchema,
    WidgetPayload,
    type TreeNode
} from './widget'

export {
    EntryKind,
    StoredEntry
} from './stored-entry'

export {
    DataState,
    ServerBroadcast,
    SessionInfo
} from './server-broadcast'

export {
    ViewerCommand
} from './viewer-command'

export {
    API_PATHS,
    API_V2_BASE_PATH,
    DEFAULT_HOST,
    DEFAULT_TCP_PORT,
    DEFAULT_UDP_PORT,
    MAX_BATCH_SIZE,
    MAX_TEXT_SIZE
} from './constants'

