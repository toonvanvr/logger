import 'dart:convert';

import 'package:flutter/material.dart';

import '../../models/log_entry.dart';
import '../../plugins/plugin_registry.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';

/// Renderer for [LogType.custom] entries.
///
/// Dispatches to specialized renderers via [PluginRegistry], or falls
/// back to a JSON dump for unknown types.
class CustomRenderer extends StatelessWidget {
  final LogEntry entry;

  const CustomRenderer({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final customType = entry.customType;
    if (customType != null) {
      final plugin = PluginRegistry.instance.resolveRenderer(customType);
      if (plugin != null) {
        final data = entry.customData;
        return plugin.buildRenderer(
          context,
          data is Map<String, dynamic> ? data : <String, dynamic>{},
          entry,
        );
      }
    }
    return _FallbackRenderer(entry: entry);
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
