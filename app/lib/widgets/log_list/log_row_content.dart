import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/log_entry.dart';
import '../../plugins/plugin_types.dart';
import '../../theme/colors.dart';
import '../../theme/constants.dart';
import '../../theme/typography.dart';
import '../renderers/renderer_factory.dart';
import 'hover_action_bar.dart';
import 'stack_badge.dart';

/// Content rendering for a log row entry.
///
/// Handles group-open rendering (collapse icon + label), depth indentation
/// with guide lines, copy-on-hover overlay, and delegates to [buildLogContent]
/// for standard entries.
class LogRowContent extends StatefulWidget {
  final LogEntry entry;
  final int groupDepth;
  final bool isCollapsed;
  final bool showGroupChevron;
  final bool isHovered;
  final Color backgroundColor;
  final int stackDepth;
  final VoidCallback? onStackToggle;
  final void Function(String entryId)? onPin;
  final void Function(String tag)? onFilterByTag;

  const LogRowContent({
    super.key,
    required this.entry,
    this.groupDepth = 0,
    this.isCollapsed = false,
    this.showGroupChevron = true,
    this.isHovered = false,
    this.backgroundColor = LoggerColors.bgSurface,
    this.stackDepth = 1,
    this.onStackToggle,
    this.onPin,
    this.onFilterByTag,
  });

  @override
  State<LogRowContent> createState() => _LogRowContentState();
}

class _LogRowContentState extends State<LogRowContent> {
  bool _copied = false;

  void _onCopy() {
    Clipboard.setData(ClipboardData(text: serializeLogEntry(widget.entry)));
    setState(() => _copied = true);
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  List<RowAction> _buildActions() {
    final actions = <RowAction>[
      RowAction(
        id: 'copy',
        icon: _copied ? Icons.check : Icons.content_copy,
        tooltip: 'Copy',
        onTap: (_) => _onCopy(),
        isActive: (_) => _copied,
      ),
    ];

    if (widget.onPin != null) {
      actions.add(
        RowAction(
          id: 'pin',
          icon: Icons.push_pin_outlined,
          tooltip: 'Pin',
          onTap: (entry) => widget.onPin!(entry.id),
        ),
      );
    }

    if (widget.onFilterByTag != null && widget.entry.tag != null) {
      actions.add(
        RowAction(
          id: 'filter_tag',
          icon: Icons.filter_alt,
          tooltip: 'Filter by tag',
          onTap: (entry) => widget.onFilterByTag!(entry.tag!),
        ),
      );
    }

    return actions;
  }

  @override
  Widget build(BuildContext context) {
    Widget content;

    // For group header entries, show collapse icon and group label
    if (widget.entry.groupId != null &&
        widget.entry.id == widget.entry.groupId) {
      final label = widget.entry.message ?? widget.entry.groupId ?? 'Group';
      final durationMs = widget.entry.labels?['_duration_ms'];
      content = Row(
        children: [
          if (widget.showGroupChevron) ...[
            Icon(
              widget.isCollapsed ? Icons.chevron_right : Icons.expand_more,
              size: 14,
              color: LoggerColors.fgSecondary,
            ),
            const SizedBox(width: 4),
          ],
          Expanded(child: Text(label, style: LoggerTypography.groupTitle)),
          if (durationMs != null) _DurationBadge(durationMs: durationMs),
        ],
      );
    } else {
      content = buildLogContent(widget.entry);
    }

    if (widget.groupDepth > 0) {
      content = Padding(
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

    if (widget.stackDepth > 1) {
      content = Row(
        children: [
          Expanded(child: content),
          StackBadge(depth: widget.stackDepth, onTap: widget.onStackToggle),
        ],
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        content,
        if (widget.isHovered)
          Positioned(
            right: widget.stackDepth > 1 ? 40 : 0,
            top: 0,
            bottom: 0,
            child: SelectionContainer.disabled(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IgnorePointer(
                    child: Container(
                      width: 32,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            widget.backgroundColor.withValues(alpha: 0),
                            widget.backgroundColor,
                          ],
                        ),
                      ),
                    ),
                  ),
                  HoverActionBar(
                    entry: widget.entry,
                    backgroundColor: widget.backgroundColor,
                    actions: _buildActions(),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _DurationBadge extends StatelessWidget {
  final String durationMs;

  const _DurationBadge({required this.durationMs});

  @override
  Widget build(BuildContext context) {
    final ms = double.tryParse(durationMs) ?? 0;
    final color = ms < 100
        ? LoggerColors.syntaxString
        : ms < 500
        ? LoggerColors.severityWarningBar
        : LoggerColors.severityErrorBar;

    final text = ms < 1000
        ? '${ms.round()}ms'
        : '${(ms / 1000).toStringAsFixed(1)}s';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(38),
        borderRadius: kBorderRadiusSm,
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: color,
          height: 1.2,
        ),
      ),
    );
  }
}

/// Serialize a log entry to a clipboard-friendly string.
String serializeLogEntry(LogEntry entry) {
  if (entry.groupId != null && entry.id == entry.groupId) {
    return entry.message ?? entry.groupId ?? 'Group';
  }
  final text = entry.message ?? '';
  if (entry.widget?.data['data'] != null) {
    try {
      final encoded = const JsonEncoder.withIndent(
        '  ',
      ).convert(entry.widget!.data['data']);
      return text.isNotEmpty ? '$text\n$encoded' : encoded;
    } catch (e) {
      debugPrint('Warning: widget data serialization failed: $e');
      return text.isNotEmpty
          ? '$text\n${entry.widget!.data['data']}'
          : '${entry.widget!.data['data']}';
    }
  }
  if (entry.widget?.data != null) {
    try {
      final encoded = const JsonEncoder.withIndent(
        '  ',
      ).convert(entry.widget!.data);
      return text.isNotEmpty ? '$text\n$encoded' : encoded;
    } catch (e) {
      debugPrint('Warning: widget data serialization failed: $e');
      return text.isNotEmpty ? text : '${entry.widget!.data}';
    }
  }
  return text;
}
