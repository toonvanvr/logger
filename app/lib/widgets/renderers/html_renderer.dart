import 'package:flutter/material.dart';

import '../../models/log_entry.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';

/// Renders HTML log content with a raw/stripped toggle.
///
/// In "stripped" mode (default), `<script>` tags, event handler
/// attributes and all remaining HTML tags are removed so only the
/// readable text remains. Toggling "View raw" shows the original HTML.
class HtmlRenderer extends StatefulWidget {
  final LogEntry entry;

  const HtmlRenderer({super.key, required this.entry});

  @override
  State<HtmlRenderer> createState() => _HtmlRendererState();
}

class _HtmlRendererState extends State<HtmlRenderer> {
  bool _showRaw = false;

  @override
  Widget build(BuildContext context) {
    final raw = widget.entry.widget?.data['content'] as String? ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => setState(() => _showRaw = !_showRaw),
          child: Text(
            _showRaw ? 'View stripped' : 'View raw',
            style: LoggerTypography.logMeta.copyWith(
              color: LoggerColors.syntaxUrl,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(_showRaw ? raw : _stripHtml(raw), style: LoggerTypography.logBody),
      ],
    );
  }

  /// Sanitise then strip tags to produce readable text.
  static String _stripHtml(String html) {
    var sanitized = html.replaceAll(
      RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false),
      '',
    );
    sanitized = sanitized.replaceAll(
      RegExp(r'\s+on\w+="[^"]*"', caseSensitive: false),
      '',
    );
    sanitized = sanitized.replaceAll(
      RegExp(r"\s+on\w+='[^']*'", caseSensitive: false),
      '',
    );
    sanitized = sanitized.replaceAll(RegExp(r'<[^>]+>'), '');
    sanitized = sanitized.replaceAll(RegExp(r'\s+'), ' ').trim();
    return sanitized;
  }
}
