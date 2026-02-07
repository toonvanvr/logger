import 'package:flutter/material.dart';

import '../../models/log_entry.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';

/// Renders a group open/close marker.
///
/// * **Open**: shows the group label as a section header with a
///   collapse indicator.
/// * **Close**: shows "End: [group label]".
class GroupRenderer extends StatelessWidget {
  final LogEntry entry;

  const GroupRenderer({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final action = entry.groupAction ?? GroupAction.open;
    final label = entry.groupLabel ?? entry.groupId ?? 'Group';
    final isCollapsed = entry.groupCollapsed ?? false;

    if (action == GroupAction.close) {
      return Text(
        'End: $label',
        style: LoggerTypography.logBody.copyWith(
          color: LoggerColors.fgSecondary,
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isCollapsed ? Icons.chevron_right : Icons.expand_more,
          size: 14,
          color: LoggerColors.fgSecondary,
        ),
        const SizedBox(width: 4),
        Text(label, style: LoggerTypography.groupTitle),
      ],
    );
  }
}
