/// Dart equivalents of the shared TypeScript LogEntry schema.
///
/// Field names use camelCase per Dart convention; JSON keys use snake_case
/// matching the wire protocol.
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

// ─── Sub-schemas ─────────────────────────────────────────────────────

class ApplicationInfo {
  final String name;
  final String? version;
  final String? environment;

  const ApplicationInfo({required this.name, this.version, this.environment});

  factory ApplicationInfo.fromJson(Map<String, dynamic> json) {
    return ApplicationInfo(
      name: json['name'] as String,
      version: json['version'] as String?,
      environment: json['environment'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    if (version != null) 'version': version,
    if (environment != null) 'environment': environment,
  };
}

class SourceLocation {
  final String uri;
  final int? line;
  final int? column;
  final String? symbol;

  const SourceLocation({
    required this.uri,
    this.line,
    this.column,
    this.symbol,
  });

  factory SourceLocation.fromJson(Map<String, dynamic> json) {
    return SourceLocation(
      uri: json['uri'] as String,
      line: json['line'] as int?,
      column: json['column'] as int?,
      symbol: json['symbol'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'uri': uri,
    if (line != null) 'line': line,
    if (column != null) 'column': column,
    if (symbol != null) 'symbol': symbol,
  };
}

class StackFrame {
  final SourceLocation location;
  final bool? isVendor;
  final String? raw;

  const StackFrame({required this.location, this.isVendor, this.raw});

  factory StackFrame.fromJson(Map<String, dynamic> json) {
    return StackFrame(
      location: SourceLocation.fromJson(
        json['location'] as Map<String, dynamic>,
      ),
      isVendor: json['isVendor'] as bool?,
      raw: json['raw'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'location': location.toJson(),
    if (isVendor != null) 'isVendor': isVendor,
    if (raw != null) 'raw': raw,
  };
}

class ExceptionData {
  final String? type;
  final String message;
  final List<StackFrame>? stackTrace;
  final ExceptionData? cause;

  const ExceptionData({
    this.type,
    required this.message,
    this.stackTrace,
    this.cause,
  });

  factory ExceptionData.fromJson(Map<String, dynamic> json) {
    return ExceptionData(
      type: json['type'] as String?,
      message: json['message'] as String,
      stackTrace: (json['stackTrace'] as List<dynamic>?)
          ?.map((e) => StackFrame.fromJson(e as Map<String, dynamic>))
          .toList(),
      cause: json['cause'] != null
          ? ExceptionData.fromJson(json['cause'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    if (type != null) 'type': type,
    'message': message,
    if (stackTrace != null)
      'stackTrace': stackTrace!.map((f) => f.toJson()).toList(),
    if (cause != null) 'cause': cause!.toJson(),
  };
}

class IconRef {
  final String icon;
  final String? color;
  final double? size;

  const IconRef({required this.icon, this.color, this.size});

  factory IconRef.fromJson(Map<String, dynamic> json) {
    return IconRef(
      icon: json['icon'] as String,
      color: json['color'] as String?,
      size: (json['size'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'icon': icon,
    if (color != null) 'color': color,
    if (size != null) 'size': size,
  };
}

class ImageData {
  final String? data;
  final String? ref;
  final String? mimeType;
  final String? label;
  final int? width;
  final int? height;

  const ImageData({
    this.data,
    this.ref,
    this.mimeType,
    this.label,
    this.width,
    this.height,
  });

  factory ImageData.fromJson(Map<String, dynamic> json) {
    return ImageData(
      data: json['data'] as String?,
      ref: json['ref'] as String?,
      mimeType: json['mimeType'] as String?,
      label: json['label'] as String?,
      width: json['width'] as int?,
      height: json['height'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
    if (data != null) 'data': data,
    if (ref != null) 'ref': ref,
    if (mimeType != null) 'mimeType': mimeType,
    if (label != null) 'label': label,
    if (width != null) 'width': width,
    if (height != null) 'height': height,
  };
}

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
