import 'package:flutter/material.dart';

import '../../models/log_entry.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';
import '../renderers/renderer_factory.dart';
import 'session_dot.dart';
import 'severity_bar.dart';

/// Compact group header row for the sticky overlay.
class StickyGroupHeader extends StatelessWidget {
  final LogEntry entry;
  final int depth;
  final bool altPressed;
  final VoidCallback? onClose;

  const StickyGroupHeader({
    super.key,
    required this.entry,
    required this.depth,
    this.altPressed = false,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final label = entry.message ?? entry.groupId ?? 'Group';

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
          const SizedBox(width: 4),
          StickyCloseButton(altPressed: altPressed, onTap: onClose),
        ],
      ),
    );
  }
}

/// A compact sticky entry row for the overlay.
class StickyEntryRow extends StatelessWidget {
  final LogEntry entry;
  final int depth;
  final bool altPressed;
  final VoidCallback? onClose;

  const StickyEntryRow({
    super.key,
    required this.entry,
    required this.depth,
    this.altPressed = false,
    this.onClose,
  });

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
              padding: const EdgeInsets.only(right: 2),
              child: SessionDot(sessionId: entry.sessionId),
            ),
            StickyCloseButton(altPressed: altPressed, onTap: onClose),
          ],
        ),
      ),
    );
  }
}

/// Clickable badge showing "N items hidden" between sticky entries.
class HiddenItemsBadge extends StatelessWidget {
  final int count;
  final String? groupId;
  final void Function(String? groupId)? onTap;
  final int depth;

  const HiddenItemsBadge({
    super.key,
    required this.count,
    this.groupId,
    this.onTap,
    this.depth = 0,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
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
            if (depth > 0)
              Container(
                width: 2,
                height: 14,
                margin: const EdgeInsets.only(right: 6),
                color: LoggerColors.borderDefault.withAlpha(64),
              ),
            Expanded(
              child: Container(
                height: 1,
                margin: const EdgeInsets.only(right: 8),
                color: LoggerColors.borderSubtle,
              ),
            ),
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
      ),
    );
  }
}

/// Close/Ignore button for a sticky entry row.
class StickyCloseButton extends StatelessWidget {
  final bool altPressed;
  final VoidCallback? onTap;

  const StickyCloseButton({super.key, this.altPressed = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
        width: 20,
        height: 20,
        child: Icon(
          altPressed ? Icons.visibility_off : Icons.close,
          size: 14,
          color: altPressed
              ? LoggerColors.severityWarningText
              : LoggerColors.fgMuted,
        ),
      ),
      ),
    );
  }
}
