import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/sticky_state.dart';
import '../../theme/colors.dart';
import 'sticky_header_entry.dart';
import 'sticky_models.dart';

export 'sticky_models.dart' show StickySection, OnHiddenTap;

/// Renders the pinned sticky entries overlay at the top of the log list.
///
/// Shows sticky entries grouped by their parent group, with compact
/// group headers and "N items hidden" indicators for non-sticky siblings.
/// Constrained to max 30% of the available viewport height.
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
    if (alt != _altPressed) setState(() => _altPressed = alt);
    return false;
  }

  static const double _estimatedSectionHeight = 44.0;

  @override
  Widget build(BuildContext context) {
    if (widget.sections.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxHeight = constraints.maxHeight * widget.maxHeightFraction;
        final expandedMax = constraints.maxHeight * 0.5;
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
                    color: LoggerColors.scrim,
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: _expanded
                  ? SingleChildScrollView(
                      child: _buildContent(visibleSections, hiddenSectionCount),
                    )
                  : SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
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
        if (widget.sections.length > 1)
          SectionCountBar(
            total: widget.sections.length,
            expanded: _expanded,
            onToggle: () => setState(() => _expanded = !_expanded),
          ),
        for (int i = 0; i < sections.length; i++) ...[
          if (i > 0) const Divider(height: 1, color: LoggerColors.borderSubtle),
          _buildSection(sections[i]),
        ],
        if (hiddenSectionCount > 0 && !_expanded)
          OverflowIndicator(
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
        if (section.groupHeader != null)
          StickyGroupHeader(
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
        for (final entry in section.entries)
          StickyEntryRow(
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
        if (section.hiddenCount > 0)
          HiddenItemsBadge(
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
