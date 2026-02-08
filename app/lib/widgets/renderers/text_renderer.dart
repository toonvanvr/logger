import 'package:flutter/material.dart';

import '../../models/log_entry.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';
import 'ansi_parser.dart';
import 'stack_trace_renderer.dart';

/// Pattern definitions for syntax highlighting in log text.
///
/// Order matters: earlier patterns take priority when regions overlap.
final _highlightPattern = RegExp(
  r'(\{\{icon:[^}]+\}\})' // icon syntax
  r'|(\w+://[^\s]+)' // URLs (all protocols)
  r"|('(?:[^'\\]|\\.)*'" // single-quoted strings
  r'|"(?:[^"\\]|\\.)*")' // double-quoted strings
  r'|(\b\d{4}-\d{2}-\d{2}' // ISO 8601 dates
  r'(?:T\d{2}:\d{2}:\d{2}'
  r'(?:\.\d+)?(?:Z|[+-]\d{2}:?\d{2})?)?'
  r'\b)'
  r'|(\btrue\b|\bfalse\b)' // booleans
  r'|(\bnull\b|\bundefined\b)' // null/undefined
  r'|(\b\d+(?:\.\d+)?(?:[eE][+-]?\d+)?\b)' // numbers
  r'|(/[\w./\\-]+(?:\.\w+)+)', // file paths
  multiLine: true,
);

/// Renders a text log entry with syntax highlighting.
///
/// Parses the text for known patterns (numbers, strings, booleans, dates,
/// URLs, file paths) and applies [LoggerColors.syntax*] colors via
/// [RichText] + [TextSpan]. When [LogEntry.exception] is present a
/// [StackTraceRenderer] is appended below the content.
class TextRenderer extends StatelessWidget {
  final LogEntry entry;

  const TextRenderer({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final text = entry.text ?? '';
    final spans = hasAnsiCodes(text) ? _buildAnsiSpans(text) : _highlight(text);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        RichText(text: TextSpan(children: spans)),
        if (entry.exception != null) ...[
          const SizedBox(height: 4),
          StackTraceRenderer(exception: entry.exception!),
        ],
      ],
    );
  }

  /// Converts ANSI-coded text into styled [TextSpan]s.
  List<TextSpan> _buildAnsiSpans(String text) {
    final segments = parseAnsi(text);
    final baseStyle = LoggerTypography.logBody;

    return segments.map((seg) {
      return TextSpan(
        text: seg.text,
        style: baseStyle.copyWith(
          color: seg.foreground ?? baseStyle.color,
          backgroundColor: seg.background,
          fontWeight: seg.bold
              ? FontWeight.w700
              : (seg.dim ? FontWeight.w300 : null),
          fontStyle: seg.italic ? FontStyle.italic : null,
          decoration: seg.underline ? TextDecoration.underline : null,
        ),
      );
    }).toList();
  }

  /// Tokenises [text] and returns a list of coloured [TextSpan]s.
  List<TextSpan> _highlight(String text) {
    final spans = <TextSpan>[];
    final baseStyle = LoggerTypography.logBody;
    var lastEnd = 0;

    for (final match in _highlightPattern.allMatches(text)) {
      // Plain text before this match.
      if (match.start > lastEnd) {
        spans.add(
          TextSpan(
            text: text.substring(lastEnd, match.start),
            style: baseStyle,
          ),
        );
      }

      final Color color;
      String matchText = match[0]!;

      if (match.group(1) != null) {
        // Icon syntax — render as placeholder text.
        final inner = matchText.substring(2, matchText.length - 2);
        final parts = inner.split(':');
        matchText = '[icon:${parts.skip(1).take(2).join(':')}]';
        color = LoggerColors.fgSecondary;
      } else if (match.group(2) != null) {
        // URL — color protocol separately, highlight port distinctly
        final protocolEnd = matchText.indexOf('://') + 3;
        spans.add(
          TextSpan(
            text: matchText.substring(0, protocolEnd),
            style: baseStyle.copyWith(color: LoggerColors.syntaxProtocol),
          ),
        );
        final rest = matchText.substring(protocolEnd);
        final portMatch = RegExp(r':(\d+)').firstMatch(rest);
        if (portMatch != null) {
          // Before port
          if (portMatch.start > 0) {
            spans.add(
              TextSpan(
                text: rest.substring(0, portMatch.start),
                style: baseStyle.copyWith(color: LoggerColors.syntaxUrl),
              ),
            );
          }
          // Port (including colon)
          spans.add(
            TextSpan(
              text: rest.substring(portMatch.start, portMatch.end),
              style: baseStyle.copyWith(color: LoggerColors.syntaxNumber),
            ),
          );
          // After port
          if (portMatch.end < rest.length) {
            spans.add(
              TextSpan(
                text: rest.substring(portMatch.end),
                style: baseStyle.copyWith(color: LoggerColors.syntaxUrl),
              ),
            );
          }
        } else {
          spans.add(
            TextSpan(
              text: rest,
              style: baseStyle.copyWith(color: LoggerColors.syntaxUrl),
            ),
          );
        }
        lastEnd = match.end;
        continue;
      } else if (match.group(3) != null) {
        color = LoggerColors.syntaxString;
      } else if (match.group(4) != null) {
        color = LoggerColors.syntaxDate;
      } else if (match.group(5) != null) {
        color = LoggerColors.syntaxBoolean;
      } else if (match.group(6) != null) {
        color = LoggerColors.syntaxNull;
      } else if (match.group(7) != null) {
        color = LoggerColors.syntaxNumber;
      } else if (match.group(8) != null) {
        color = LoggerColors.syntaxPath;
      } else {
        color = baseStyle.color!;
      }

      spans.add(
        TextSpan(
          text: matchText,
          style: baseStyle.copyWith(color: color),
        ),
      );
      lastEnd = match.end;
    }

    // Trailing plain text.
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd), style: baseStyle));
    }

    // Ensure at least one span so RichText never receives an empty list.
    if (spans.isEmpty) {
      spans.add(TextSpan(text: '', style: baseStyle));
    }

    return spans;
  }
}
