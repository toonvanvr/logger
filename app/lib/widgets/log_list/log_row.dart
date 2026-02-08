import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/log_entry.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';
import '../renderers/renderer_factory.dart';
import 'session_dot.dart';
import 'severity_bar.dart';

/// A single log row in the log list.
///
/// Displays a severity bar on the left, log content in the center, and a
/// session color dot on the right. Supports fade-in animation for new entries
/// and an unseen highlight that fades out over time.
class LogRow extends StatefulWidget {
  final LogEntry entry;
  final bool isNew;
  final bool isEvenRow;
  final bool isSelected;
  final int groupDepth;
  final VoidCallback? onGroupToggle;
  final bool isCollapsed;
  final VoidCallback? onTap;

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
  });

  @override
  State<LogRow> createState() => _LogRowState();
}

class _LogRowState extends State<LogRow> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _isHovered = false;

  /// Highlight animation for unseen entries: warm amber glow that fades out.
  late final Animation<Color?> _highlightAnimation;

  /// Opacity animation for new entries: fade from 0 → 1.
  late final Animation<double> _opacityAnimation;

  /// Translate-Y animation for new entries: slide up 4dp.
  late final Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();

    if (widget.isNew) {
      // New entry: 150ms fade-in + slide-up, then 500ms hold, then 2000ms
      // highlight fade-out. Total controller duration covers all phases.
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2800),
      );

      // Phase 1: fade-in + slide (0–150ms → 0.0–~0.054 of total 2800ms)
      _opacityAnimation = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _controller,
          curve: const Interval(0, 0.054, curve: Curves.easeOut),
        ),
      );

      _slideAnimation = Tween<double>(begin: 4, end: 0).animate(
        CurvedAnimation(
          parent: _controller,
          curve: const Interval(0, 0.054, curve: Curves.easeOut),
        ),
      );

      // Phase 2: warm highlight appear (0–300ms → 0–0.107), hold until 800ms
      // (0.286), then fade out 800ms–2800ms (0.286–1.0).
      const highlightColor = Color(0x18E6B455); // #E6B45518
      _highlightAnimation = TweenSequence<Color?>([
        TweenSequenceItem(
          tween: ColorTween(begin: Colors.transparent, end: highlightColor),
          weight: 300, // 300ms appear
        ),
        TweenSequenceItem(
          tween: ConstantTween<Color?>(highlightColor),
          weight: 500, // 500ms hold
        ),
        TweenSequenceItem(
          tween: ColorTween(begin: highlightColor, end: Colors.transparent),
          weight: 2000, // 2000ms fade
        ),
      ]).animate(_controller);

      _controller.forward();
    } else {
      // Already-seen entry: no animation.
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
    if (widget.isSelected) return LoggerColors.bgActive;
    if (widget.isEvenRow) return LoggerColors.bgSurface;
    // Alternate row: very subtle stripe.
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
            child: SelectionContainer.disabled(
              child: GestureDetector(
                onTap: widget.onGroupToggle ?? widget.onTap,
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
                  // Stack the highlight color over the base background.
                  foregroundDecoration:
                      _highlightAnimation.value != null &&
                          _highlightAnimation.value != Colors.transparent
                      ? BoxDecoration(color: _highlightAnimation.value)
                      : null,
                  child: child,
                ),
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
              SeverityBar(severity: widget.entry.severity),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  child: _buildContent(),
                ),
              ),
              if (_isHovered)
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: _serializeEntry()));
                  },
                  child: const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Icon(
                      Icons.content_copy,
                      size: 14,
                      color: LoggerColors.fgMuted,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: SessionDot(sessionId: widget.entry.sessionId),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _serializeEntry() {
    final entry = widget.entry;
    if (entry.type == LogType.group) {
      return entry.groupLabel ?? entry.groupId ?? 'Group';
    }
    final text = entry.text ?? '';
    if (entry.jsonData != null) {
      try {
        final encoded = const JsonEncoder.withIndent(
          '  ',
        ).convert(entry.jsonData);
        return text.isNotEmpty ? '$text\n$encoded' : encoded;
      } catch (_) {
        return text.isNotEmpty
            ? '$text\n${entry.jsonData}'
            : '${entry.jsonData}';
      }
    }
    if (entry.customData != null) {
      try {
        final encoded = const JsonEncoder.withIndent(
          '  ',
        ).convert(entry.customData);
        return text.isNotEmpty ? '$text\n$encoded' : encoded;
      } catch (_) {
        return text.isNotEmpty ? text : '${entry.customData}';
      }
    }
    return text;
  }

  Widget _buildContent() {
    Widget content;

    // For group open entries, override the collapse icon based on actual state
    if (widget.entry.type == LogType.group &&
        widget.entry.groupAction == GroupAction.open) {
      final label = widget.entry.groupLabel ?? widget.entry.groupId ?? 'Group';
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            widget.isCollapsed ? Icons.chevron_right : Icons.expand_more,
            size: 14,
            color: LoggerColors.fgSecondary,
          ),
          const SizedBox(width: 4),
          Text(label, style: LoggerTypography.groupTitle),
        ],
      );
    } else {
      content = buildLogContent(widget.entry);
    }

    if (widget.groupDepth > 0) {
      return Padding(
        padding: EdgeInsets.only(left: widget.groupDepth * 12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 2,
              constraints: const BoxConstraints(minHeight: 16),
              margin: const EdgeInsets.only(right: 6),
              color: LoggerColors.borderDefault.withAlpha(128),
            ),
            Expanded(child: content),
          ],
        ),
      );
    }

    return content;
  }
}
