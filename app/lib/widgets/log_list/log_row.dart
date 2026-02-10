import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../models/log_entry.dart';
import '../../theme/colors.dart';
import 'log_row_content.dart';
import 'session_dot.dart';
import 'severity_bar.dart';

/// A single log row in the log list with severity bar, content, and session dot.
class LogRow extends StatefulWidget {
  final LogEntry entry;
  final bool isNew;
  final bool isEvenRow;
  final bool isSelected;
  final int groupDepth;
  final VoidCallback? onGroupToggle;
  final bool isCollapsed;
  final VoidCallback? onTap;
  final bool selectionMode;
  final bool isSelectionSelected;
  final VoidCallback? onSelect;
  final bool isBookmarked;
  final int stackDepth;
  final VoidCallback? onStackToggle;

  const LogRow({
    super.key,
    required this.entry,
    this.isNew = false,
    this.isEvenRow = false,
    this.isSelected = false,
    this.groupDepth = 0,
    this.onGroupToggle,
    this.isCollapsed = false,
    this.onTap,
    this.selectionMode = false,
    this.isSelectionSelected = false,
    this.onSelect,
    this.isBookmarked = false,
    this.stackDepth = 1,
    this.onStackToggle,
  });

  @override
  State<LogRow> createState() => _LogRowState();
}

class _LogRowState extends State<LogRow> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final ValueNotifier<bool> _hoverNotifier = ValueNotifier(false);
  late final Animation<Color?> _highlightAnimation;
  late final Animation<double> _opacityAnimation;
  late final Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();

    if (widget.isNew) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2000),
      );
      _opacityAnimation = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _controller,
          curve: const Interval(0, 0.075, curve: Curves.easeOut),
        ),
      );
      _slideAnimation = Tween<double>(begin: 4, end: 0).animate(
        CurvedAnimation(
          parent: _controller,
          curve: const Interval(0, 0.075, curve: Curves.easeOut),
        ),
      );
      const highlightColor = LoggerColors.highlight;
      _highlightAnimation = TweenSequence<Color?>([
        TweenSequenceItem(
          tween: ColorTween(begin: Colors.transparent, end: highlightColor),
          weight: 150, // 150ms appear
        ),
        TweenSequenceItem(
          tween: ConstantTween<Color?>(highlightColor),
          weight: 200, // 200ms hold
        ),
        TweenSequenceItem(
          tween: ColorTween(begin: highlightColor, end: Colors.transparent),
          weight: 1650, // 1650ms fade
        ),
      ]).animate(_controller);
      _controller.forward();
    } else {
      _controller = AnimationController(vsync: this, duration: Duration.zero);
      _opacityAnimation = const AlwaysStoppedAnimation(1);
      _slideAnimation = const AlwaysStoppedAnimation(0);
      _highlightAnimation = const AlwaysStoppedAnimation(Colors.transparent);
    }
  }

  @override
  void dispose() {
    _hoverNotifier.dispose();
    _controller.dispose();
    super.dispose();
  }

  Offset? _pointerDownPosition;

  Color _computeBackgroundColor(bool isHovered) {
    final base = widget.isSelectionSelected
        ? LoggerColors.bgActive
        : (widget.isEvenRow
              ? LoggerColors.bgSurface
              : LoggerColors.bgSurface.withValues(alpha: 0.85));
    if (isHovered) return Color.lerp(base, Colors.white, 0.03)!;
    return base;
  }

  /// Wraps [child] in either a [GestureDetector] (selection mode) or a
  /// [Listener] (normal mode). Using [Listener] for raw pointer events
  /// avoids entering the gesture arena so that an ancestor [SelectionArea]
  /// can still recognise double-click (word) and triple-click (paragraph)
  /// text selection.
  Widget _buildTapHandler({required Widget child}) {
    if (widget.selectionMode) {
      return GestureDetector(onTap: widget.onSelect, child: child);
    }
    return Listener(
      onPointerDown: _handlePointerDown,
      onPointerUp: _handlePointerUp,
      child: child,
    );
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (event.buttons == kPrimaryButton) {
      _pointerDownPosition = event.position;
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (_pointerDownPosition != null) {
      final distance = (event.position - _pointerDownPosition!).distance;
      _pointerDownPosition = null;
      if (distance < kTouchSlop) {
        (widget.onGroupToggle ?? widget.onTap)?.call();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value),
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: _buildTapHandler(
              child: ValueListenableBuilder<bool>(
                valueListenable: _hoverNotifier,
                builder: (context, isHovered, innerChild) {
                  return Container(
                    constraints: const BoxConstraints(minHeight: 24),
                    decoration: BoxDecoration(
                      color: _computeBackgroundColor(isHovered),
                      border: Border(
                        bottom: BorderSide(
                          color: LoggerColors.borderSubtle,
                          width: 1,
                        ),
                      ),
                    ),
                    foregroundDecoration:
                        _highlightAnimation.value != null &&
                            _highlightAnimation.value != Colors.transparent
                        ? BoxDecoration(color: _highlightAnimation.value)
                        : null,
                    child: innerChild,
                  );
                },
                child: child,
              ),
            ),
          ),
        );
      },
      child: MouseRegion(
        onEnter: (_) => _hoverNotifier.value = true,
        onExit: (_) => _hoverNotifier.value = false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
              if (widget.selectionMode)
                GestureDetector(
                  onTap: widget.onSelect,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      widget.isSelectionSelected
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      size: 14,
                      color: widget.isSelectionSelected
                          ? LoggerColors.borderFocus
                          : LoggerColors.fgMuted,
                    ),
                  ),
                ),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 24),
                child: SeverityBar(severity: widget.entry.severity),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  child: ValueListenableBuilder<bool>(
                    valueListenable: _hoverNotifier,
                    builder: (context, isHovered, _) {
                      return LogRowContent(
                        entry: widget.entry,
                        groupDepth: widget.groupDepth,
                        isCollapsed: widget.isCollapsed,
                        isHovered: isHovered,
                        backgroundColor: _computeBackgroundColor(isHovered),
                        stackDepth: widget.stackDepth,
                        onStackToggle: widget.onStackToggle,
                      );
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: SessionDot(sessionId: widget.entry.sessionId),
              ),
              if (widget.isBookmarked)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(
                    Icons.bookmark,
                    size: 12,
                    color: LoggerColors.borderFocus,
                  ),
                ),
            ],
          ),
      ),
    );
  }
}
