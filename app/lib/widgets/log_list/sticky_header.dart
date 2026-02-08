import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/log_entry.dart';
import '../../services/sticky_state.dart';
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
///
/// Does NOT create its own scroll context — content is clipped with
/// [ClipRect] so pointer/scroll events propagate to the parent.
class StickyHeaderOverlay extends StatefulWidget {
  final List<StickySection> sections;
  final double maxHeightFraction;
  final OnHiddenTap? onHiddenTap;
  final StickyStateService? stickyState;

  const StickyHeaderOverlay({
    super.key,
    required this.sections,
    this.maxHeightFraction = 0.3,
    this.onHiddenTap,
    this.stickyState,
  });

  @override
  State<StickyHeaderOverlay> createState() => _StickyHeaderOverlayState();
}

class _StickyHeaderOverlayState extends State<StickyHeaderOverlay> {
  bool _altPressed = false;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKey);
    super.dispose();
  }

  bool _handleKey(KeyEvent event) {
    final alt =
        HardwareKeyboard.instance.logicalKeysPressed.contains(
          LogicalKeyboardKey.altLeft,
        ) ||
        HardwareKeyboard.instance.logicalKeysPressed.contains(
          LogicalKeyboardKey.altRight,
        );
    if (alt != _altPressed) {
      setState(() => _altPressed = alt);
    }
    return false; // Don't consume the event.
  }

  /// Estimated height per section (header + ~1 entry + badge).
  static const double _estimatedSectionHeight = 44.0;

  @override
  Widget build(BuildContext context) {
    if (widget.sections.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxHeight = constraints.maxHeight * widget.maxHeightFraction;
        final expandedMax = constraints.maxHeight * 0.5;

        // S08: Overflow detection.
        final fitsInMax =
            widget.sections.length * _estimatedSectionHeight <= maxHeight;
        final visibleSections = _expanded || fitsInMax
            ? widget.sections
            : _sectionsToFit(widget.sections, maxHeight);
        final hiddenSectionCount =
            widget.sections.length - visibleSections.length;

        return AnimatedSize(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: _expanded ? expandedMax : maxHeight,
            ),
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
              child: _expanded
                  ? SingleChildScrollView(
                      child: _buildContent(visibleSections, hiddenSectionCount),
                    )
                  : ClipRect(
                      child: _buildContent(visibleSections, hiddenSectionCount),
                    ),
            ),
          ),
        );
      },
    );
  }

  List<StickySection> _sectionsToFit(
    List<StickySection> sections,
    double maxHeight,
  ) {
    final count = (maxHeight / _estimatedSectionHeight).floor().clamp(
      1,
      sections.length,
    );
    return sections.sublist(0, count);
  }

  Widget _buildContent(List<StickySection> sections, int hiddenSectionCount) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Section count indicator.
        if (widget.sections.length > 1)
          _SectionCountBar(
            total: widget.sections.length,
            expanded: _expanded,
            onToggle: () => setState(() => _expanded = !_expanded),
          ),
        for (int i = 0; i < sections.length; i++) ...[
          if (i > 0) const Divider(height: 1, color: LoggerColors.borderSubtle),
          _buildSection(sections[i]),
        ],
        // S08: Overflow indicator.
        if (hiddenSectionCount > 0 && !_expanded)
          _OverflowIndicator(
            count: hiddenSectionCount,
            onTap: () => setState(() => _expanded = true),
          ),
      ],
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
            altPressed: _altPressed,
            onClose: () {
              if (_altPressed) {
                final gid =
                    section.groupHeader!.groupId ?? section.groupHeader!.id;
                widget.stickyState?.ignore(gid);
              } else {
                widget.stickyState?.dismiss(section.groupHeader!.id);
              }
            },
          ),

        // Sticky entries
        for (final entry in section.entries)
          _StickyEntryRow(
            entry: entry,
            depth: section.groupHeader != null
                ? section.groupDepth + 1
                : section.groupDepth,
            altPressed: _altPressed,
            onClose: () {
              if (_altPressed && entry.groupId != null) {
                widget.stickyState?.ignore(entry.groupId!);
              } else {
                widget.stickyState?.dismiss(entry.id);
              }
            },
          ),

        // Hidden items indicator
        if (section.hiddenCount > 0)
          _HiddenItemsBadge(
            count: section.hiddenCount,
            groupId: section.groupHeader?.groupId,
            onTap: widget.onHiddenTap,
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
  final bool altPressed;
  final VoidCallback? onClose;

  const _StickyGroupHeader({
    required this.entry,
    required this.depth,
    this.altPressed = false,
    this.onClose,
  });

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
          const SizedBox(width: 4),
          _CloseButton(altPressed: altPressed, onTap: onClose),
        ],
      ),
    );
  }
}

/// A compact sticky entry row for the overlay.
class _StickyEntryRow extends StatelessWidget {
  final LogEntry entry;
  final int depth;
  final bool altPressed;
  final VoidCallback? onClose;

  const _StickyEntryRow({
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
              padding: const EdgeInsets.only(right: 2),
              child: SessionDot(sessionId: entry.sessionId),
            ),
            _CloseButton(altPressed: altPressed, onTap: onClose),
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

/// Close/Ignore button for a sticky entry row.
///
/// Shows [Icons.close] normally, [Icons.visibility_off] when Alt is held.
class _CloseButton extends StatelessWidget {
  final bool altPressed;
  final VoidCallback? onTap;

  const _CloseButton({this.altPressed = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
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
    );
  }
}

/// Top bar showing "N sections pinned" with expand/collapse toggle.
class _SectionCountBar extends StatelessWidget {
  final int total;
  final bool expanded;
  final VoidCallback onToggle;

  const _SectionCountBar({
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
        padding: const EdgeInsets.symmetric(horizontal: 8),
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
                fontSize: 8,
                color: LoggerColors.fgSecondary,
              ),
            ),
            const Spacer(),
            Text(
              expanded ? 'collapse' : 'expand',
              style: LoggerTypography.badge.copyWith(
                fontSize: 8,
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
class _OverflowIndicator extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _OverflowIndicator({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 18,
        padding: const EdgeInsets.symmetric(horizontal: 8),
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
              fontSize: 8,
              color: LoggerColors.borderFocus,
            ),
          ),
        ),
      ),
    );
  }
}
