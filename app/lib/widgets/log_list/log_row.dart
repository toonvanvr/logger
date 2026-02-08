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
  });

  @override
  State<LogRow> createState() => _LogRowState();
}

class _LogRowState extends State<LogRow> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _isHovered = false;
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
    _controller.dispose();
    super.dispose();
  }

  Color get _backgroundColor {
    if (widget.isSelectionSelected) return LoggerColors.bgActive;
    if (widget.isSelected) return LoggerColors.bgActive;
    if (widget.isEvenRow) return LoggerColors.bgSurface;
    return LoggerColors.bgSurface.withValues(alpha: 0.85);
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
            child: GestureDetector(
              onTap: widget.selectionMode
                  ? widget.onSelect
                  : (widget.onGroupToggle ?? widget.onTap),
              child: Container(
                constraints: const BoxConstraints(minHeight: 24),
                decoration: BoxDecoration(
                  color: _highlightAnimation.value ?? _backgroundColor,
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
                child: child,
              ),
            ),
          ),
        );
      },
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
              SeverityBar(severity: widget.entry.severity),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  child: LogRowContent(
                    entry: widget.entry,
                    groupDepth: widget.groupDepth,
                    isCollapsed: widget.isCollapsed,
                    isHovered: _isHovered,
                    backgroundColor: _backgroundColor,
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
      ),
    );
  }
}
