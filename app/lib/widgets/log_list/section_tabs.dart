import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../theme/colors.dart';
import '../../theme/typography.dart';

/// Tabs for filtering logs by tag (State, Events, custom tags).
///
/// Tags appear only when logs with that tag name have been received.
/// Supports horizontal scrolling with arrow buttons when tabs overflow.
class SectionTabs extends StatefulWidget {
  final List<String> tags;
  final String? selectedTag;
  final ValueChanged<String?> onTagChanged;

  const SectionTabs({
    super.key,
    required this.tags,
    required this.selectedTag,
    required this.onTagChanged,
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
    if (widget.tags.length <= 1) return const SizedBox.shrink();

    return Container(
      height: 28,
      color: LoggerColors.bgRaised,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          if (_canScrollLeft || _canScrollRight)
            AnimatedOpacity(
              opacity: _canScrollLeft ? 1.0 : 0.3,
              duration: const Duration(milliseconds: 150),
              child: _ArrowButton(
                icon: Icons.chevron_left,
                onTap: _canScrollLeft ? () => _scrollBy(-80) : null,
              ),
            ),
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
                      isSelected: widget.selectedTag == null,
                      onTap: () => widget.onTagChanged(null),
                    ),
                    for (final section in widget.tags)
                      _SectionTab(
                        label: section.toUpperCase(),
                        isSelected: widget.selectedTag == section,
                        onTap: () => widget.onTagChanged(section),
                      ),
                  ],
                ),
              ),
            ),
          ),
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

class _SectionTab extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SectionTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_SectionTab> createState() => _SectionTabState();
}

class _SectionTabState extends State<_SectionTab> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.isSelected
        ? LoggerColors.fgPrimary
        : _isHovered
        ? LoggerColors.fgPrimary
        : LoggerColors.fgSecondary;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: widget.isSelected
                    ? LoggerColors.borderFocus
                    : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          alignment: Alignment.center,
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 100),
            style: LoggerTypography.sectionH.copyWith(color: color),
            child: Text(widget.label),
          ),
        ),
      ),
    );
  }
}
