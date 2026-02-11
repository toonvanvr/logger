import 'package:flutter/material.dart';

import '../../models/log_entry.dart';
import '../plugin_manifest.dart';
import '../plugin_registry.dart';
import '../plugin_types.dart';

/// Filter plugin for HTTP request entries.
///
/// Supports structured queries: `http:status=404`, `http:status=5xx`,
/// `http:method=GET`, `http:url~pattern`, `http:slow`, `http:error`,
/// `http:request_id=abc`.
class HttpFilterPlugin extends FilterPlugin with EnableablePlugin {
  // ─── Identity ──────────────────────────────────────────────────────

  @override
  String get id => 'dev.logger.http-filter';

  @override
  String get name => 'HTTP Filter';

  @override
  String get version => '1.0.0';

  @override
  String get description =>
      'Filters HTTP entries by status, method, URL, speed, and errors.';

  @override
  PluginManifest get manifest => const PluginManifest(
    id: 'dev.logger.http-filter',
    name: 'HTTP Filter',
    version: '1.0.0',
    description:
        'Filters HTTP entries by status, method, URL, speed, and errors.',
    types: ['filter'],
  );

  @override
  String get filterLabel => 'HTTP';

  @override
  IconData get filterIcon => Icons.http;

  // ─── FilterPlugin interface ────────────────────────────────────────

  @override
  bool matches(LogEntry entry, String query) {
    final data = entry.widget?.data;
    if (data == null || entry.widget?.type != 'http_request') return false;
    if (!query.startsWith('http:')) return false;

    final expr = query.substring(5); // strip "http:"

    // http:slow
    if (expr == 'slow') {
      final dur = (data['duration_ms'] as num?)?.toInt();
      return dur != null && dur >= 1000;
    }

    // http:error
    if (expr == 'error') {
      final isError = data['is_error'] == true;
      final status = (data['status'] as num?)?.toInt();
      return isError || (status != null && status >= 400);
    }

    // http:status=NNN or http:status=Nxx
    if (expr.startsWith('status=')) {
      final val = expr.substring(7);
      final status = (data['status'] as num?)?.toInt();
      if (status == null) return false;
      if (val.contains('x') || val.contains('X')) {
        final classDigit = int.tryParse(val[0]);
        if (classDigit == null) return false;
        return status >= classDigit * 100 && status < (classDigit + 1) * 100;
      }
      return status == int.tryParse(val);
    }

    // http:method=GET
    if (expr.startsWith('method=')) {
      final val = expr.substring(7).toUpperCase();
      final method = (data['method'] as String?)?.toUpperCase();
      return method == val;
    }

    // http:url~pattern
    if (expr.startsWith('url~')) {
      final pattern = expr.substring(4).toLowerCase();
      final url = (data['url'] as String?)?.toLowerCase();
      return url != null && url.contains(pattern);
    }

    // http:request_id=abc
    if (expr.startsWith('request_id=')) {
      final val = expr.substring(11);
      return data['request_id'] == val;
    }

    return false;
  }

  @override
  List<String> getSuggestions(String partialQuery, List<LogEntry> entries) {
    final statics = [
      'http:error',
      'http:slow',
      'http:status=',
      'http:method=',
      'http:url~',
      'http:request_id=',
    ];

    final httpEntries = entries.where(
      (e) => e.widget?.type == 'http_request' && e.widget != null,
    );

    final dynamic = <String>{};

    for (final e in httpEntries) {
      final d = e.widget!.data;
      final status = (d['status'] as num?)?.toInt();
      if (status != null) dynamic.add('http:status=$status');
      final method = d['method'] as String?;
      if (method != null) dynamic.add('http:method=$method');
    }

    final all = [...statics, ...dynamic.toList()..sort()];
    if (partialQuery.isEmpty) return all;
    final lower = partialQuery.toLowerCase();
    return all.where((s) => s.toLowerCase().contains(lower)).toList();
  }

  // ─── Lifecycle ─────────────────────────────────────────────────────

  @override
  void onRegister(PluginRegistry registry) {}

  @override
  void onDispose() {}
}
