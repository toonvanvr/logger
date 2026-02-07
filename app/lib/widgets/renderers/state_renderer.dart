import 'dart:convert';

import 'package:flutter/material.dart';

import '../../models/log_entry.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';

/// Renders a state key-value pair.
///
/// Shows `stateKey: stateValue` with pretty-printed JSON for object
/// values. A null [LogEntry.stateValue] is shown as a delete indicator.
class StateRenderer extends StatelessWidget {
  final LogEntry entry;

  const StateRenderer({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final key = entry.stateKey ?? 'unknown';
    final value = entry.stateValue;
    final isDeleted = value == null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$key: ',
          style: LoggerTypography.logBody.copyWith(
            color: LoggerColors.syntaxKey,
          ),
        ),
        Flexible(
          child: isDeleted
              ? Text(
                  'deleted',
                  style: LoggerTypography.logBody.copyWith(
                    color: LoggerColors.severityErrorText,
                    fontStyle: FontStyle.italic,
                  ),
                )
              : Text(_formatValue(value), style: LoggerTypography.logBody),
        ),
      ],
    );
  }

  static String _formatValue(dynamic value) {
    if (value is Map || value is List) {
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(value);
    }
    return value.toString();
  }
}
