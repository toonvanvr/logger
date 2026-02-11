import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../models/log_entry.dart';
import '../../theme/colors.dart';
import 'log_row_content.dart';
import 'session_dot.dart';
import 'severity_bar.dart';

/// A single log row — delegates to [_AnimatedLogRow] (ticker) or
/// [_StaticLogRow] (no ticker) based on [isNew].
class LogRow extends StatelessWidget {
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
  final bool showGroupChevron;

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
    this.showGroupChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    if (isNew) return _AnimatedLogRow(parent: this);
    return _StaticLogRow(parent: this);
  }
}

/// Shared hover, pointer, tap, background and row-body logic.
mixin _LogRowInteraction<T extends StatefulWidget> on State<T> {
  LogRow get _row;
  final ValueNotifier<bool> hoverNotifier = ValueNotifier(false);
  Offset? _pointerDownPosition;

  @override
  void dispose() {
    hoverNotifier.dispose();
    super.dispose();
  }

  Color computeBackground(bool isHovered) {
    final base = _row.isSelectionSelected
        ? LoggerColors.bgActive
        : (_row.isEvenRow
              ? LoggerColors.bgSurface
              : LoggerColors.bgSurface.withValues(alpha: 0.85));
    if (isHovered) return Color.lerp(base, Colors.white, 0.06)!;
    return base;
  }

  /// Wraps [child] in [GestureDetector] (selection) or [Listener] (normal).
  Widget buildTapHandler({required Widget child}) {
    if (_row.selectionMode) {
      return GestureDetector(onTap: _row.onSelect, child: child);
    }
    return Listener(
      onPointerDown: _handlePointerDown,
      onPointerUp: _handlePointerUp,
      child: child,
    );
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (event.buttons == kPrimaryButton) _pointerDownPosition = event.position;
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (_pointerDownPosition != null) {
      final distance = (event.position - _pointerDownPosition!).distance;
      _pointerDownPosition = null;
      if (distance < kTouchSlop) {
        (_row.onGroupToggle ?? _row.onTap)?.call();
      }
    }
  }

  Widget buildRowBody() {
    return MouseRegion(
      onEnter: (_) => hoverNotifier.value = true,
      onExit: (_) => hoverNotifier.value = false,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 22,
            child: _row.selectionMode
                ? MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: _row.onSelect,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          _row.isSelectionSelected
                              ? Icons.check_box
                              : Icons.check_box_outline_blank,
                          size: 14,
                          color: _row.isSelectionSelected
                              ? LoggerColors.borderFocus
                              : LoggerColors.fgMuted,
                        ),
                      ),
                    ),
                  )
                : null,
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 24),
            child: SeverityBar(severity: _row.entry.severity),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: ValueListenableBuilder<bool>(
                valueListenable: hoverNotifier,
                builder: (context, isHovered, _) {
                  return LogRowContent(
                    entry: _row.entry,
                    groupDepth: _row.groupDepth,
                    isCollapsed: _row.isCollapsed,
                    showGroupChevron: _row.showGroupChevron,
                    isHovered: isHovered,
                    backgroundColor: computeBackground(isHovered),
                    stackDepth: _row.stackDepth,
                    onStackToggle: _row.onStackToggle,
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: SessionDot(sessionId: _row.entry.sessionId),
          ),
          if (_row.isBookmarked)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(
                Icons.bookmark, size: 12, color: LoggerColors.borderFocus,
              ),
            ),
        ],
      ),
    );
  }
}

class _StaticLogRow extends StatefulWidget {
  final LogRow parent;
  const _StaticLogRow({required this.parent});

  @override
  State<_StaticLogRow> createState() => _StaticLogRowState();
}

class _StaticLogRowState extends State<_StaticLogRow>
    with _LogRowInteraction<_StaticLogRow> {
  @override
  LogRow get _row => widget.parent;

  @override
  Widget build(BuildContext context) {
    return buildTapHandler(
      child: ValueListenableBuilder<bool>(
        valueListenable: hoverNotifier,
        builder: (context, isHovered, child) {
          return Container(
            constraints: const BoxConstraints(minHeight: 24),
            decoration: BoxDecoration(
              color: computeBackground(isHovered),
              border: Border(
                bottom: BorderSide(
                  color: LoggerColors.borderSubtle, width: 1,
                ),
              ),
            ),
            child: child,
          );
        },
        child: buildRowBody(),
      ),
    );
  }
}

class _AnimatedLogRow extends StatefulWidget {
  final LogRow parent;
  const _AnimatedLogRow({required this.parent});

  @override
  State<_AnimatedLogRow> createState() => _AnimatedLogRowState();
}

class _AnimatedLogRowState extends State<_AnimatedLogRow>
    with SingleTickerProviderStateMixin, _LogRowInteraction<_AnimatedLogRow> {
  @override
  LogRow get _row => widget.parent;
  late final AnimationController _controller;
  late final Animation<Color?> _highlightAnimation;
  late final Animation<double> _opacityAnimation;
  late final Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2000));
    _opacityAnimation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.075, curve: Curves.easeOut),
    ));
    _slideAnimation = Tween<double>(begin: 4, end: 0).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.075, curve: Curves.easeOut),
    ));
    const hl = LoggerColors.highlight;
    _highlightAnimation = TweenSequence<Color?>([
      TweenSequenceItem(
        tween: ColorTween(begin: Colors.transparent, end: hl), weight: 150),
      TweenSequenceItem(
        tween: ConstantTween<Color?>(hl), weight: 200),
      TweenSequenceItem(
        tween: ColorTween(begin: hl, end: Colors.transparent), weight: 1650),
    ]).animate(_controller);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
            child: buildTapHandler(
              child: ValueListenableBuilder<bool>(
                valueListenable: hoverNotifier,
                builder: (context, isHovered, innerChild) {
                  return Container(
                    constraints: const BoxConstraints(minHeight: 24),
                    decoration: BoxDecoration(
                      color: computeBackground(isHovered),
                      border: Border(
                        bottom: BorderSide(
                          color: LoggerColors.borderSubtle, width: 1,
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
      child: buildRowBody(),
    );
  }
}
