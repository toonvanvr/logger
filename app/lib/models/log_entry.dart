/// Dart equivalents of the v2 StoredEntry schema.
///
/// Field names use camelCase per Dart convention; JSON keys use snake_case
/// matching the wire protocol.
library;

import 'log_enums.dart';
import 'log_sub_models.dart';

export 'log_enums.dart';
export 'log_sub_models.dart';

// ─── LogEntry ────────────────────────────────────────────────────────

class LogEntry {
  // Core (all entries)
  final String id;
  final String timestamp;
  final String sessionId;
  final EntryKind kind;
  final Severity severity;

  // Event fields (null when kind ≠ event)
  final String? message;
  final String? tag;
  final ExceptionData? exception;
  final String? parentId;
  final String? groupId;
  final String? prevId;
  final String? nextId;
  final WidgetPayload? widget;
  final bool replace;
  final IconRef? icon;
  final Map<String, String>? labels;
  final String? generatedAt;
  final String? sentAt;

  // Data fields (null when kind ≠ data)
  final String? key;
  final dynamic value;
  final bool override_;
  final DisplayLocation display;

  // Session fields (null when kind ≠ session)
  final SessionAction? sessionAction;
  final ApplicationInfo? application;
  final Map<String, dynamic>? metadata;

  // Server-assigned
  final String? receivedAt;

  const LogEntry({
    required this.id,
    required this.timestamp,
    required this.sessionId,
    required this.kind,
    required this.severity,
    this.message,
    this.tag,
    this.exception,
    this.parentId,
    this.groupId,
    this.prevId,
    this.nextId,
    this.widget,
    this.replace = false,
    this.icon,
    this.labels,
    this.generatedAt,
    this.sentAt,
    this.key,
    this.value,
    this.override_ = true,
    this.display = DisplayLocation.defaultLoc,
    this.sessionAction,
    this.application,
    this.metadata,
    this.receivedAt,
  });

  factory LogEntry.fromJson(Map<String, dynamic> json) {
    return LogEntry(
      id: json['id'] as String,
      timestamp: json['timestamp'] as String,
      sessionId: json['session_id'] as String,
      kind: parseEntryKind(json['kind'] as String),
      severity: parseSeverity(json['severity'] as String? ?? 'info'),
      message: json['message'] as String?,
      tag: json['tag'] as String?,
      exception: json['exception'] != null
          ? ExceptionData.fromJson(json['exception'] as Map<String, dynamic>)
          : null,
      parentId: json['parent_id'] as String?,
      groupId: json['group_id'] as String?,
      prevId: json['prev_id'] as String?,
      nextId: json['next_id'] as String?,
      widget: json['widget'] != null
          ? WidgetPayload.fromJson(json['widget'] as Map<String, dynamic>)
          : null,
      replace: json['replace'] as bool? ?? false,
      icon: json['icon'] != null
          ? IconRef.fromJson(json['icon'] as Map<String, dynamic>)
          : null,
      labels: (json['labels'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, v as String),
      ),
      generatedAt: json['generated_at'] as String?,
      sentAt: json['sent_at'] as String?,
      key: json['key'] as String?,
      value: json['value'],
      override_: json['override'] as bool? ?? true,
      display: parseDisplayLocation(json['display'] as String? ?? 'default'),
      sessionAction: parseSessionAction(json['session_action'] as String?),
      application: json['application'] != null
          ? ApplicationInfo.fromJson(
              json['application'] as Map<String, dynamic>,
            )
          : null,
      metadata: json['metadata'] as Map<String, dynamic>?,
      receivedAt: json['received_at'] as String?,
    );
  }
}
