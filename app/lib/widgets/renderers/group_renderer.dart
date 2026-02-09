import 'package:flutter/material.dart';

import '../../models/log_entry.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';

/// Renders a group header.
///
/// Shows the group label with an expand indicator.
/// In v2, groups have no explicit open/close actions — a group is
/// identified by [LogEntry.groupId] being non-null.
class GroupRenderer extends StatelessWidget {
  final LogEntry entry;

  const GroupRenderer({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final label = entry.message ?? entry.groupId ?? 'Group';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.expand_more, size: 14, color: LoggerColors.fgSecondary),
        const SizedBox(width: 4),
        Text(label, style: LoggerTypography.groupTitle),
      ],
    );
  }
}
