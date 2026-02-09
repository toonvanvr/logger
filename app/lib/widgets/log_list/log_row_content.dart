import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/log_entry.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';
import '../renderers/renderer_factory.dart';

/// Content rendering for a log row entry.
///
/// Handles group-open rendering (collapse icon + label), depth indentation
/// with guide lines, copy-on-hover overlay, and delegates to [buildLogContent]
/// for standard entries.
class LogRowContent extends StatefulWidget {
  final LogEntry entry;
  final int groupDepth;
  final bool isCollapsed;
  final bool isHovered;
  final Color backgroundColor;

  const LogRowContent({
    super.key,
    required this.entry,
    this.groupDepth = 0,
    this.isCollapsed = false,
    this.isHovered = false,
    this.backgroundColor = LoggerColors.bgSurface,
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

  @override
  Widget build(BuildContext context) {
    Widget content;

    // For group open entries, show collapse icon and group label
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

    return Stack(
      clipBehavior: Clip.none,
      children: [
        content,
        if (widget.isHovered)
          Positioned(
            right: 0,
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
                  _CopyButton(
                    copied: _copied,
                    onTap: _onCopy,
                    backgroundColor: widget.backgroundColor,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _CopyButton extends StatefulWidget {
  final bool copied;
  final VoidCallback onTap;
  final Color backgroundColor;

  const _CopyButton({
    required this.copied,
    required this.onTap,
    required this.backgroundColor,
  });

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.copied
        ? LoggerColors.syntaxString
        : _hovered
        ? LoggerColors.fgPrimary
        : LoggerColors.fgMuted;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 24,
          color: widget.backgroundColor,
          alignment: Alignment.center,
          child: Icon(
            widget.copied ? Icons.check : Icons.content_copy,
            size: widget.copied ? 12 : 14,
            color: color,
          ),
        ),
      ),
    );
  }
}

/// Serialize a log entry to a clipboard-friendly string.
String serializeLogEntry(LogEntry entry) {
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
      return text.isNotEmpty ? '$text\n${entry.jsonData}' : '${entry.jsonData}';
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
