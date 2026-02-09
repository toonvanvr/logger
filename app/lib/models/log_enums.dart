/// Enum types for the v2 log entry schema.
///
/// Shared between [LogEntry] and various widgets/services.
library;

// ─── Enums ───────────────────────────────────────────────────────────

enum Severity { debug, info, warning, error, critical }

enum EntryKind { session, event, data }

enum DisplayLocation { defaultLoc, static_, shelf }

enum SessionAction { start, end, heartbeat }

// ─── Helper: enum ↔ string ──────────────────────────────────────────

Severity parseSeverity(String value) => Severity.values.firstWhere(
  (e) => e.name == value,
  orElse: () => Severity.debug,
);

EntryKind parseEntryKind(String value) => switch (value) {
  'session' => EntryKind.session,
  'event' => EntryKind.event,
  'data' => EntryKind.data,
  _ => EntryKind.event,
};

DisplayLocation parseDisplayLocation(String value) => switch (value) {
  'default' => DisplayLocation.defaultLoc,
  'static' => DisplayLocation.static_,
  'shelf' => DisplayLocation.shelf,
  _ => DisplayLocation.defaultLoc,
};

SessionAction? parseSessionAction(String? value) {
  if (value == null) return null;
  return SessionAction.values.firstWhere(
    (e) => e.name == value,
    orElse: () => SessionAction.start,
  );
}
