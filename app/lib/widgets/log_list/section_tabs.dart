import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../theme/colors.dart';
import '../../theme/typography.dart';

/// Tabs for filtering logs by section (State, Events, custom sections).
///
/// Sections appear only when logs with that section name have been received.
/// Supports horizontal scrolling with arrow buttons when tabs overflow.
class SectionTabs extends StatefulWidget {
  final List<String> sections;
  final String? selectedSection;
  final ValueChanged<String?> onSectionChanged;

  const SectionTabs({
    super.key,
    required this.sections,
    required this.selectedSection,
    required this.onSectionChanged,
  });

  @override
  State<SectionTabs> createState() => _SectionTabsState();
}

class _SectionTabsState extends State<SectionTabs> {
  final ScrollController _scrollController = ScrollController();
  bool _canScrollLeft = false;
  bool _canScrollRight = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateScrollState);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateScrollState());
  }

  @override
  void didUpdateWidget(SectionTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateScrollState());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateScrollState);
    _scrollController.dispose();
    super.dispose();
  }

  void _updateScrollState() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    final newCanLeft = pos.pixels > 0;
    final newCanRight = pos.pixels < pos.maxScrollExtent;
    if (newCanLeft != _canScrollLeft || newCanRight != _canScrollRight) {
      setState(() {
        _canScrollLeft = newCanLeft;
        _canScrollRight = newCanRight;
      });
    }
  }

  void _scrollBy(double delta) {
    if (!_scrollController.hasClients) return;
    final target = (_scrollController.offset + delta).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.sections.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 28,
      color: LoggerColors.bgRaised,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          // Left arrow
          if (_canScrollLeft || _canScrollRight)
            AnimatedOpacity(
              opacity: _canScrollLeft ? 1.0 : 0.3,
              duration: const Duration(milliseconds: 150),
              child: _ArrowButton(
                icon: Icons.chevron_left,
                onTap: _canScrollLeft ? () => _scrollBy(-80) : null,
              ),
            ),
          // Scrollable tab row
          Expanded(
            child: Listener(
              onPointerSignal: (event) {
                if (event is PointerScrollEvent) {
                  _scrollBy(event.scrollDelta.dy);
                }
              },
              child: SingleChildScrollView(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _SectionTab(
                      label: 'ALL',
                      isSelected: widget.selectedSection == null,
                      onTap: () => widget.onSectionChanged(null),
                    ),
                    for (final section in widget.sections)
                      _SectionTab(
                        label: section.toUpperCase(),
                        isSelected: widget.selectedSection == section,
                        onTap: () => widget.onSectionChanged(section),
                      ),
                  ],
                ),
              ),
            ),
          ),
          // Right arrow
          if (_canScrollLeft || _canScrollRight)
            AnimatedOpacity(
              opacity: _canScrollRight ? 1.0 : 0.3,
              duration: const Duration(milliseconds: 150),
              child: _ArrowButton(
                icon: Icons.chevron_right,
                onTap: _canScrollRight ? () => _scrollBy(80) : null,
              ),
            ),
        ],
      ),
    );
  }
}

class _ArrowButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _ArrowButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Icon(icon, size: 16, color: LoggerColors.fgSecondary),
      ),
    );
  }
}

class _SectionTab extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SectionTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? LoggerColors.borderFocus : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: LoggerTypography.sectionH.copyWith(
            color: isSelected
                ? LoggerColors.fgPrimary
                : LoggerColors.fgSecondary,
          ),
        ),
      ),
    );
  }
}
