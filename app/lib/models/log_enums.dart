/// Enum types for the log entry schema.
///
/// Shared between [LogEntry] and various widgets/services.
library;

// ─── Enums ───────────────────────────────────────────────────────────

enum Severity { debug, info, warning, error, critical }

enum LogType {
  text,
  json,
  html,
  binary,
  image,
  state,
  group,
  rpc,
  session,
  custom,
}

enum GroupAction { open, close }

enum SessionAction { start, end, heartbeat }

enum RpcDirection { request, response, error }

// ─── Helper: enum ↔ string ──────────────────────────────────────────

Severity parseSeverity(String value) => Severity.values.firstWhere(
  (e) => e.name == value,
  orElse: () => Severity.debug,
);

LogType parseLogType(String value) => LogType.values.firstWhere(
  (e) => e.name == value,
  orElse: () => LogType.text,
);

GroupAction? parseGroupAction(String? value) {
  if (value == null) return null;
  return GroupAction.values.firstWhere(
    (e) => e.name == value,
    orElse: () => GroupAction.open,
  );
}

SessionAction? parseSessionAction(String? value) {
  if (value == null) return null;
  return SessionAction.values.firstWhere(
    (e) => e.name == value,
    orElse: () => SessionAction.start,
  );
}

RpcDirection? parseRpcDirection(String? value) {
  if (value == null) return null;
  return RpcDirection.values.firstWhere(
    (e) => e.name == value,
    orElse: () => RpcDirection.request,
  );
}
