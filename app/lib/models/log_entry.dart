/// Dart equivalents of the shared TypeScript LogEntry schema.
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
  // Required fields
  final String id;
  final String timestamp;
  final String sessionId;
  final Severity severity;
  final LogType type;

  // Application metadata
  final ApplicationInfo? application;

  // Section targeting
  final String? section;

  // Content fields (type-dependent)
  final String? text;
  final dynamic jsonData; // mapped from "json" key
  final String? html;
  final String? binary;
  final ImageData? image;

  // Exception
  final ExceptionData? exception;

  // Icon
  final IconRef? icon;

  // Group operations
  final String? groupId;
  final GroupAction? groupAction;
  final String? groupLabel;
  final bool? groupCollapsed;

  // Sticky pinning
  final bool? sticky;

  // State operations
  final String? stateKey;
  final dynamic stateValue;

  // Session control
  final SessionAction? sessionAction;

  // Ordering hints
  final String? afterId;
  final String? beforeId;

  // 2-Way RPC
  final String? rpcId;
  final RpcDirection? rpcDirection;
  final String? rpcMethod;
  final dynamic rpcArgs;
  final dynamic rpcResponse;
  final String? rpcError;

  // Request timing metadata
  final String? generatedAt;
  final String? sentAt;

  // Tags
  final Map<String, String>? tags;

  // In-place updates
  final bool? replace;

  // Custom type
  final String? customType;
  final dynamic customData;

  const LogEntry({
    required this.id,
    required this.timestamp,
    required this.sessionId,
    required this.severity,
    required this.type,
    this.application,
    this.section,
    this.text,
    this.jsonData,
    this.html,
    this.binary,
    this.image,
    this.exception,
    this.icon,
    this.groupId,
    this.groupAction,
    this.groupLabel,
    this.groupCollapsed,
    this.sticky,
    this.stateKey,
    this.stateValue,
    this.sessionAction,
    this.afterId,
    this.beforeId,
    this.rpcId,
    this.rpcDirection,
    this.rpcMethod,
    this.rpcArgs,
    this.rpcResponse,
    this.rpcError,
    this.generatedAt,
    this.sentAt,
    this.tags,
    this.replace,
    this.customType,
    this.customData,
  });

  factory LogEntry.fromJson(Map<String, dynamic> json) {
    return LogEntry(
      id: json['id'] as String,
      timestamp: json['timestamp'] as String,
      sessionId: json['session_id'] as String,
      severity: parseSeverity(json['severity'] as String),
      type: parseLogType(json['type'] as String),
      application: json['application'] != null
          ? ApplicationInfo.fromJson(
              json['application'] as Map<String, dynamic>,
            )
          : null,
      section: json['section'] as String?,
      text: json['text'] as String?,
      jsonData: json['json'],
      html: json['html'] as String?,
      binary: json['binary'] as String?,
      image: json['image'] != null
          ? ImageData.fromJson(json['image'] as Map<String, dynamic>)
          : null,
      exception: json['exception'] != null
          ? ExceptionData.fromJson(json['exception'] as Map<String, dynamic>)
          : null,
      icon: json['icon'] != null
          ? IconRef.fromJson(json['icon'] as Map<String, dynamic>)
          : null,
      groupId: json['group_id'] as String?,
      groupAction: parseGroupAction(json['group_action'] as String?),
      groupLabel: json['group_label'] as String?,
      groupCollapsed: json['group_collapsed'] as bool?,
      sticky: json['sticky'] as bool?,
      stateKey: json['state_key'] as String?,
      stateValue: json['state_value'],
      sessionAction: parseSessionAction(json['session_action'] as String?),
      afterId: json['after_id'] as String?,
      beforeId: json['before_id'] as String?,
      rpcId: json['rpc_id'] as String?,
      rpcDirection: parseRpcDirection(json['rpc_direction'] as String?),
      rpcMethod: json['rpc_method'] as String?,
      rpcArgs: json['rpc_args'],
      rpcResponse: json['rpc_response'],
      rpcError: json['rpc_error'] as String?,
      generatedAt: json['generated_at'] as String?,
      sentAt: json['sent_at'] as String?,
      tags: (json['tags'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, v as String),
      ),
      replace: json['replace'] as bool?,
      customType: json['custom_type'] as String?,
      customData: json['custom_data'],
    );
  }
}
