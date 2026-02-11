import '../../models/log_entry.dart';
import 'package:flutter/material.dart';

import '../../theme/colors.dart';
import '../../theme/constants.dart';
import '../../theme/typography.dart';

/// A section of sticky entries grouped under an optional parent group header.
class StickySection {
  final LogEntry? groupHeader;
  final List<LogEntry> entries;
  final int hiddenCount;
  final int groupDepth;

  const StickySection({
    this.groupHeader,
    required this.entries,
    this.hiddenCount = 0,
    this.groupDepth = 0,
  });
}

/// Callback for when "N items hidden" badge is tapped.
typedef OnHiddenTap = void Function(String? groupId);

/// Top bar showing "N sections pinned" with expand/collapse toggle.
class SectionCountBar extends StatelessWidget {
  final int total;
  final bool expanded;
  final VoidCallback onToggle;

  const SectionCountBar({
    super.key,
    required this.total,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 16,
        padding: kHPadding8,
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: LoggerColors.borderSubtle, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            Text(
              '$total sections pinned',
              style: LoggerTypography.badge.copyWith(
                fontSize: kFontSizeBadge,
                color: LoggerColors.fgSecondary,
              ),
            ),
            const Spacer(),
            Text(
              expanded ? 'collapse' : 'expand',
              style: LoggerTypography.badge.copyWith(
                fontSize: kFontSizeBadge,
                color: LoggerColors.borderFocus,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Overflow indicator when sticky sections exceed 30% viewport.
class OverflowIndicator extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const OverflowIndicator({
    super.key,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 18,
        padding: kHPadding8,
        decoration: const BoxDecoration(
          color: LoggerColors.bgOverlay,
          border: Border(
            top: BorderSide(color: LoggerColors.borderSubtle, width: 0.5),
          ),
        ),
        child: Center(
          child: Text(
            '$count more hidden...',
            style: LoggerTypography.badge.copyWith(
              fontSize: kFontSizeBadge,
              color: LoggerColors.borderFocus,
            ),
          ),
        ),
      ),
    );
  }
}
