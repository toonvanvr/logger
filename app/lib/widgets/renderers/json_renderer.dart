import 'dart:convert';

import 'package:flutter/material.dart';

import '../../models/log_entry.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';

/// Interactive JSON tree viewer for log entries of type [LogType.json].
///
/// Collapsed by default — shows `{…}` / `[…]` with a property count.
/// Tap to expand. Syntax coloured: keys in blue, strings in green,
/// numbers in amber, booleans in red, null in gray.
class JsonRenderer extends StatelessWidget {
  final LogEntry entry;

  const JsonRenderer({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final data = entry.widget?.data['data'];

    if (data == null) {
      return Text('[null]', style: LoggerTypography.logBody);
    }

    // If jsonData is a raw string, attempt to parse it.
    dynamic parsed = data;
    if (data is String) {
      try {
        parsed = jsonDecode(data);
      } catch (_) {
        return Text(data, style: LoggerTypography.logBody);
      }
    }

    return JsonNodeWidget(keyName: null, value: parsed, depth: 0);
  }
}

/// Recursively renders a single JSON node (object, array, or primitive).
class JsonNodeWidget extends StatefulWidget {
  final String? keyName;
  final dynamic value;
  final int depth;
  final bool initiallyExpanded;

  const JsonNodeWidget({
    super.key,
    required this.keyName,
    required this.value,
    this.depth = 0,
    this.initiallyExpanded = false,
  });

  @override
  State<JsonNodeWidget> createState() => _JsonNodeWidgetState();
}

class _JsonNodeWidgetState extends State<JsonNodeWidget> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  // Max recursion depth.
  static const _maxDepth = 10;

  @override
  Widget build(BuildContext context) {
    final value = widget.value;
    final isMap = value is Map;
    final isList = value is List;

    if (!isMap && !isList) {
      return _buildPrimitive();
    }

    final int count = isMap ? value.length : (value as List).length;
    final String bracket = isMap ? '{…}' : '[…]';
    final String openBracket = isMap ? '{' : '[';
    final String closeBracket = isMap ? '}' : ']';

    if (!_expanded) {
      return _buildCollapsed(bracket, count);
    }

    if (widget.depth >= _maxDepth) {
      return _buildCollapsed(bracket, count);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildToggle(openBracket, count),
        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: _buildChildren(value),
        ),
        Padding(
          padding: EdgeInsets.only(left: widget.depth > 0 ? 0 : 0),
          child: Text(
            closeBracket,
            style: LoggerTypography.logBody.copyWith(
              color: LoggerColors.syntaxPunctuation,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCollapsed(String bracket, int count) {
    return GestureDetector(
      onTap: widget.depth < _maxDepth
          ? () => setState(() => _expanded = true)
          : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.keyName != null) ...[
            Text(
              '"${widget.keyName}": ',
              style: LoggerTypography.logBody.copyWith(
                color: LoggerColors.syntaxKey,
              ),
            ),
          ],
          Text(
            '$bracket ($count)',
            style: LoggerTypography.logBody.copyWith(
              color: LoggerColors.syntaxPunctuation,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggle(String bracket, int count) {
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.keyName != null) ...[
            Text(
              '"${widget.keyName}": ',
              style: LoggerTypography.logBody.copyWith(
                color: LoggerColors.syntaxKey,
              ),
            ),
          ],
          Text(
            '$bracket  // $count items',
            style: LoggerTypography.logBody.copyWith(
              color: LoggerColors.syntaxPunctuation,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChildren(dynamic value) {
    if (value is Map) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: value.entries.map<Widget>((e) {
          return JsonNodeWidget(
            keyName: e.key.toString(),
            value: e.value,
            depth: widget.depth + 1,
          );
        }).toList(),
      );
    }

    final list = value as List;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: list.asMap().entries.map<Widget>((e) {
        return JsonNodeWidget(
          keyName: '${e.key}',
          value: e.value,
          depth: widget.depth + 1,
        );
      }).toList(),
    );
  }

  Widget _buildPrimitive() {
    final value = widget.value;
    final Color color;
    final String display;

    if (value == null) {
      color = LoggerColors.syntaxNull;
      display = 'null';
    } else if (value is bool) {
      color = LoggerColors.syntaxBoolean;
      display = value.toString();
    } else if (value is num) {
      color = LoggerColors.syntaxNumber;
      display = value.toString();
    } else {
      color = LoggerColors.syntaxString;
      display = '"$value"';
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.keyName != null) ...[
          Text(
            '"${widget.keyName}": ',
            style: LoggerTypography.logBody.copyWith(
              color: LoggerColors.syntaxKey,
            ),
          ),
        ],
        Text(display, style: LoggerTypography.logBody.copyWith(color: color)),
      ],
    );
  }
}
