import 'package:flutter/material.dart';

import '../../../../theme/colors.dart';

/// Format byte count to human-readable string.
String formatBytes(int? bytes) {
  if (bytes == null) return '';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// Classify HTTP status code into color and display label.
(Color, String) classifyStatus(
  int? status,
  bool? isError, {
  String? statusText,
}) {
  if (status == null && isError != true) {
    return (LoggerColors.fgMuted, 'PENDING');
  }
  if (status == null && isError == true) {
    return (LoggerColors.severityErrorText, 'TIMEOUT');
  }
  final label = statusText != null ? '$status $statusText' : '$status';
  if (status == 101) return (LoggerColors.syntaxUrl, label);
  if (status! >= 500) return (LoggerColors.severityErrorText, label);
  if (status >= 400) return (LoggerColors.severityWarningText, label);
  if (status >= 300) return (LoggerColors.fgSecondary, label);
  if (status >= 200) return (LoggerColors.severityInfoText, label);
  return (LoggerColors.fgMuted, label);
}

/// Color for HTTP method badge. GET=syntaxKey, others=syntaxString.
Color methodColor(String method) =>
    method == 'GET' ? LoggerColors.syntaxKey : LoggerColors.syntaxString;

/// Color for duration display based on threshold.
Color durationColor(int? durationMs) {
  if (durationMs == null) return LoggerColors.fgMuted;
  if (durationMs < 200) return LoggerColors.fgSecondary;
  if (durationMs < 1000) return LoggerColors.syntaxNumber;
  return LoggerColors.severityErrorText;
}

/// Generate a cURL command from HTTP request data.
String generateCurl(Map<String, dynamic> data) {
  final method = data['method'] as String? ?? 'GET';
  final url = data['url'] as String? ?? '';
  final headers = data['request_headers'] as Map<String, dynamic>?;
  final body = data['request_body'] as String?;

  final parts = <String>['curl', '-X', method, _shellQuote(url)];
  if (headers != null) {
    for (final entry in headers.entries) {
      parts.add('-H ${_shellQuote('${entry.key}: ${entry.value}')}');
    }
  }
  if (body != null && body.isNotEmpty) {
    parts.add('-d ${_shellQuote(body)}');
  }
  return parts.join(' ');
}

String _shellQuote(String s) => "'${s.replaceAll("'", "'\\''")}'";

/// Parse a URL into decoded components.
({String? scheme, String? host, String path, Map<String, String> queryParams})
    parseUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) {
    return (scheme: null, host: null, path: url, queryParams: {});
  }
  return (
    scheme: uri.scheme.isNotEmpty ? uri.scheme : null,
    host: uri.host.isNotEmpty ? uri.host : null,
    path: uri.path.isNotEmpty ? uri.path : '/',
    queryParams: uri.queryParameters,
  );
}

/// Decode URL-encoded string for display.
String decodeUrlForDisplay(String url) {
  try {
    return Uri.decodeFull(url);
  } catch (_) {
    return url;
  }
}
