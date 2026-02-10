/// Exception and stack trace model classes used by [LogEntry].
///
/// Contains [SourceLocation], [StackFrame], and [ExceptionData].
library;

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
  final String? stackTrace;
  final ExceptionData? inner;
  final String? source;
  final bool handled;

  const ExceptionData({
    this.type,
    required this.message,
    this.stackTrace,
    this.inner,
    this.source,
    this.handled = true,
  });

  factory ExceptionData.fromJson(Map<String, dynamic> json) {
    return ExceptionData(
      type: json['type'] as String?,
      message: json['message'] as String,
      stackTrace: json['stack_trace'] as String?,
      inner: json['inner'] != null
          ? ExceptionData.fromJson(json['inner'] as Map<String, dynamic>)
          : null,
      source: json['source'] as String?,
      handled: (json['handled'] as bool?) ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    if (type != null) 'type': type,
    'message': message,
    if (stackTrace != null) 'stack_trace': stackTrace,
    if (inner != null) 'inner': inner!.toJson(),
    if (source != null) 'source': source,
    'handled': handled,
  };
}
