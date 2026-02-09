/// Sub-model classes used by [LogEntry].
///
/// These represent nested structures within the log entry JSON schema.
library;

import 'log_enums.dart';

// ─── ApplicationInfo ─────────────────────────────────────────────────

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

// ─── SourceLocation ──────────────────────────────────────────────────

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

// ─── StackFrame ──────────────────────────────────────────────────────

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

// ─── ExceptionData ───────────────────────────────────────────────────

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

// ─── IconRef ─────────────────────────────────────────────────────────

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

// ─── ImageData ───────────────────────────────────────────────────────

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

// ─── WidgetPayload ───────────────────────────────────────────────────

class WidgetPayload {
  final String type;
  final Map<String, dynamic> data;

  const WidgetPayload({required this.type, required this.data});

  factory WidgetPayload.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    final data = Map<String, dynamic>.from(json)..remove('type');
    return WidgetPayload(type: type, data: data);
  }

  Map<String, dynamic> toJson() => {'type': type, ...data};
}

// ─── DataState ───────────────────────────────────────────────────────

class DataState {
  final dynamic value;
  final List<dynamic>? history;
  final DisplayLocation display;
  final WidgetPayload? widget;
  final String? label;
  final IconRef? icon;
  final String? updatedAt;

  const DataState({
    required this.value,
    this.history,
    this.display = DisplayLocation.defaultLoc,
    this.widget,
    this.label,
    this.icon,
    this.updatedAt,
  });

  factory DataState.fromJson(Map<String, dynamic> json) {
    return DataState(
      value: json['value'],
      history: json['history'] as List<dynamic>?,
      display: parseDisplayLocation(json['display'] as String? ?? 'default'),
      widget: json['widget'] != null
          ? WidgetPayload.fromJson(json['widget'] as Map<String, dynamic>)
          : null,
      label: json['label'] as String?,
      icon: json['icon'] != null
          ? IconRef.fromJson(json['icon'] as Map<String, dynamic>)
          : null,
      updatedAt: json['updated_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'value': value,
    if (history != null) 'history': history,
    'display': switch (display) {
      DisplayLocation.defaultLoc => 'default',
      DisplayLocation.static_ => 'static',
      DisplayLocation.shelf => 'shelf',
    },
    if (widget != null) 'widget': widget!.toJson(),
    if (label != null) 'label': label,
    if (icon != null) 'icon': icon!.toJson(),
    if (updatedAt != null) 'updated_at': updatedAt,
  };
}
