import 'dart:convert';

import 'package:flutter/material.dart';

import '../../models/log_entry.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';

/// Fallback renderer for [LogType.custom] entries.
///
/// Shows the custom type label and a JSON dump of custom data if present.
class CustomRenderer extends StatelessWidget {
  final LogEntry entry;

  const CustomRenderer({super.key, required this.entry});

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
