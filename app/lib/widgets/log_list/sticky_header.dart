import 'package:flutter/material.dart';

import '../../models/log_entry.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';
import '../renderers/renderer_factory.dart';
import 'session_dot.dart';
import 'severity_bar.dart';

/// A section of sticky entries grouped under an optional parent group header.
class StickySection {
  /// The group-open entry that is the parent of these sticky entries.
  /// Null for top-level (ungrouped) sticky entries.
  final LogEntry? groupHeader;

  /// The sticky entries within this section.
  final List<LogEntry> entries;

  /// Number of non-sticky siblings hidden between/around sticky entries.
  final int hiddenCount;

  /// Depth of the group (for indentation).
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

/// Renders the pinned sticky entries overlay at the top of the log list.
///
/// Shows sticky entries grouped by their parent group, with compact
/// group headers and "N items hidden" indicators for non-sticky siblings.
/// Constrained to max 30% of the available viewport height.
class StickyEntriesHeader extends StatelessWidget {
  final List<StickySection> sections;
  final double maxHeightFraction;
  final OnHiddenTap? onHiddenTap;

  const StickyEntriesHeader({
    super.key,
    required this.sections,
    this.maxHeightFraction = 0.3,
    this.onHiddenTap,
  });

  @override
  Widget build(BuildContext context) {
    if (sections.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxHeight = constraints.maxHeight * maxHeightFraction;

        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Container(
            decoration: BoxDecoration(
              color: LoggerColors.bgRaised,
              border: const Border(
                bottom: BorderSide(
                  color: LoggerColors.borderDefault,
                  width: 1.5,
                ),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x40000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (int i = 0; i < sections.length; i++) ...[
                    if (i > 0)
                      const Divider(
                        height: 1,
                        color: LoggerColors.borderSubtle,
                      ),
                    _buildSection(sections[i]),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSection(StickySection section) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Group header (if this section is within a group)
        if (section.groupHeader != null)
          _StickyGroupHeader(
            entry: section.groupHeader!,
            depth: section.groupDepth,
          ),

        // Sticky entries
        for (final entry in section.entries)
          _StickyEntryRow(
            entry: entry,
            depth: section.groupHeader != null
                ? section.groupDepth + 1
                : section.groupDepth,
          ),

        // Hidden items indicator
        if (section.hiddenCount > 0)
          _HiddenItemsBadge(
            count: section.hiddenCount,
            groupId: section.groupHeader?.groupId,
            onTap: onHiddenTap,
            depth: section.groupHeader != null
                ? section.groupDepth + 1
                : section.groupDepth,
          ),
      ],
    );
  }
}

/// Compact group header row for the sticky overlay.
class _StickyGroupHeader extends StatelessWidget {
  final LogEntry entry;
  final int depth;

  const _StickyGroupHeader({required this.entry, required this.depth});

  @override
  Widget build(BuildContext context) {
    final label = entry.groupLabel ?? entry.groupId ?? 'Group';

    return Container(
      constraints: const BoxConstraints(minHeight: 22),
      padding: EdgeInsets.only(
        left: 8.0 + depth * 12.0,
        right: 8,
        top: 2,
        bottom: 2,
      ),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: LoggerColors.borderSubtle, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // Left border connector
          if (depth > 0)
            Container(
              width: 2,
              height: 16,
              margin: const EdgeInsets.only(right: 6),
              color: LoggerColors.borderDefault.withAlpha(128),
            ),
          Icon(Icons.expand_more, size: 12, color: LoggerColors.fgSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: LoggerTypography.groupTitle.copyWith(fontSize: 11),
          ),
          const SizedBox(width: 8),
          // Pinned indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: LoggerColors.borderFocus.withAlpha(30),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(
                color: LoggerColors.borderFocus.withAlpha(80),
                width: 0.5,
              ),
            ),
            child: Text(
              'PINNED',
              style: LoggerTypography.badge.copyWith(
                fontSize: 8,
                color: LoggerColors.borderFocus,
                letterSpacing: 0.6,
              ),
            ),
          ),
          const Spacer(),
          SessionDot(sessionId: entry.sessionId),
        ],
      ),
    );
  }
}

/// A compact sticky entry row for the overlay.
class _StickyEntryRow extends StatelessWidget {
  final LogEntry entry;
  final int depth;

  const _StickyEntryRow({required this.entry, required this.depth});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 22),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: LoggerColors.borderSubtle, width: 0.5),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SeverityBar(severity: entry.severity),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 8.0 + depth * 12.0,
                  right: 8,
                  top: 1,
                  bottom: 1,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left border connector for nested entries
                    if (depth > 0)
                      Container(
                        width: 2,
                        constraints: const BoxConstraints(minHeight: 14),
                        margin: const EdgeInsets.only(right: 6),
                        color: LoggerColors.borderDefault.withAlpha(128),
                      ),
                    Expanded(child: buildLogContent(entry)),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: SessionDot(sessionId: entry.sessionId),
            ),
          ],
        ),
      ),
    );
  }
}

/// Clickable badge showing "N items hidden" between sticky entries.
class _HiddenItemsBadge extends StatelessWidget {
  final int count;
  final String? groupId;
  final OnHiddenTap? onTap;
  final int depth;

  const _HiddenItemsBadge({
    required this.count,
    this.groupId,
    this.onTap,
    this.depth = 0,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap != null ? () => onTap!(groupId) : null,
      child: Container(
        height: 18,
        padding: EdgeInsets.only(left: 8.0 + depth * 12.0, right: 8),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: LoggerColors.borderSubtle, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            // Left connector
            if (depth > 0)
              Container(
                width: 2,
                height: 14,
                margin: const EdgeInsets.only(right: 6),
                color: LoggerColors.borderDefault.withAlpha(64),
              ),
            // Dashed line indicator
            Expanded(
              child: Container(
                height: 1,
                margin: const EdgeInsets.only(right: 8),
                color: LoggerColors.borderSubtle,
              ),
            ),
            // Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: LoggerColors.bgOverlay,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: LoggerColors.borderDefault,
                  width: 0.5,
                ),
              ),
              child: Text(
                '$count item${count == 1 ? '' : 's'} hidden',
                style: LoggerTypography.badge.copyWith(
                  fontSize: 8,
                  color: LoggerColors.fgSecondary,
                ),
              ),
            ),
            // Dashed line indicator
            Expanded(
              child: Container(
                height: 1,
                margin: const EdgeInsets.only(left: 8),
                color: LoggerColors.borderSubtle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
