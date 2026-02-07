import 'dart:convert';

import 'package:flutter/material.dart';

import '../../models/log_entry.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';
import 'custom/kv_renderer.dart';
import 'custom/progress_renderer.dart';
import 'custom/table_renderer.dart';

/// Renderer for [LogType.custom] entries.
///
/// Dispatches to specialized renderers by [LogEntry.customType], or falls
/// back to a JSON dump for unknown types.
class CustomRenderer extends StatelessWidget {
  final LogEntry entry;

  const CustomRenderer({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    switch (entry.customType) {
      case 'progress':
        return ProgressRenderer(entry: entry);
      case 'table':
        return TableRenderer(entry: entry);
      case 'kv':
        return KvRenderer(entry: entry);
      default:
        return _FallbackRenderer(entry: entry);
    }
  }
}

class _FallbackRenderer extends StatelessWidget {
  final LogEntry entry;

  const _FallbackRenderer({required this.entry});

  @override
  Widget build(BuildContext context) {
    final type = entry.customType ?? 'custom';
    final data = entry.customData;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '[$type]',
          style: LoggerTypography.logBody.copyWith(
            color: LoggerColors.fgSecondary,
          ),
        ),
        if (data != null) ...[
          const SizedBox(height: 2),
          Text(_formatData(data), style: LoggerTypography.logBody),
        ],
      ],
    );
  }

  static String _formatData(dynamic data) {
    if (data is Map || data is List) {
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(data);
    }
    return data.toString();
  }
}
