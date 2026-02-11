import 'package:flutter/material.dart';

import '../../models/log_entry.dart';
import '../../theme/colors.dart';
import '../../theme/constants.dart';
import '../../theme/typography.dart';
import 'stack_timeline.dart';

/// Inline expansion panel showing all versions of a stacked log entry.
class StackExpansionPanel extends StatelessWidget {
  final List<LogEntry> stack;
  final int activeIndex;
  final ValueChanged<int>? onVersionSelected;

  const StackExpansionPanel({
    super.key,
    required this.stack,
    required this.activeIndex,
    this.onVersionSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: LoggerColors.bgRaised,
        border: Border(
          bottom: BorderSide(color: LoggerColors.borderSubtle, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          StackTimeline(
            count: stack.length,
            activeIndex: activeIndex,
            onSelect: onVersionSelected,
          ),
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.builder(
              shrinkWrap: true,
              physics: const ClampingScrollPhysics(),
              itemCount: stack.length,
              itemBuilder: (context, i) => _buildVersionRow(i, stack[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVersionRow(int index, LogEntry entry) {
    final isActive = index == activeIndex;
    return GestureDetector(
      onTap: () => onVersionSelected?.call(index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
        decoration: BoxDecoration(
          color: isActive ? LoggerColors.bgActive : Colors.transparent,
          borderRadius: kBorderRadiusSm,
        ),
        child: Row(
          children: [
            Text(
              '#${index + 1}',
              style: LoggerTypography.logMeta.copyWith(
                color: isActive
                    ? LoggerColors.borderFocus
                    : LoggerColors.fgMuted,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                entry.message ?? '(no message)',
                style: LoggerTypography.logBody.copyWith(
                  fontSize: 11,
                  color: isActive
                      ? LoggerColors.fgPrimary
                      : LoggerColors.fgSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(_formatTime(entry.timestamp), style: LoggerTypography.logMeta),
          ],
        ),
      ),
    );
  }

  String _formatTime(String timestamp) {
    try {
      final dt = DateTime.parse(timestamp);
      return '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}:'
          '${dt.second.toString().padLeft(2, '0')}';
    } catch (e) {
      debugPrint('Warning: timestamp parse failed: $e');
      return timestamp;
    }
  }
}
