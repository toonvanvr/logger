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
class LogRowContent extends StatelessWidget {
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
  Widget build(BuildContext context) {
    Widget content;

    // For group open entries, show collapse icon and group label
    if (entry.type == LogType.group && entry.groupAction == GroupAction.open) {
      final label = entry.groupLabel ?? entry.groupId ?? 'Group';
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isCollapsed ? Icons.chevron_right : Icons.expand_more,
            size: 14,
            color: LoggerColors.fgSecondary,
          ),
          const SizedBox(width: 4),
          Text(label, style: LoggerTypography.groupTitle),
        ],
      );
    } else {
      content = buildLogContent(entry);
    }

    if (groupDepth > 0) {
      content = Padding(
        padding: EdgeInsets.only(left: groupDepth * 12.0),
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

    if (!isHovered) return content;

    return Stack(
      children: [
        content,
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          child: SelectionContainer.disabled(
            child: GestureDetector(
              onTap: () => Clipboard.setData(
                ClipboardData(text: serializeLogEntry(entry)),
              ),
              child: Container(
                width: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      backgroundColor.withValues(alpha: 0),
                      backgroundColor,
                    ],
                  ),
                ),
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 4),
                child: const Icon(
                  Icons.content_copy,
                  size: 14,
                  color: LoggerColors.fgMuted,
                ),
              ),
            ),
          ),
        ),
      ],
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
