import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../theme/colors.dart';
import '../../../../theme/typography.dart';

/// Headers masked by default for security.
const _sensitiveHeaders = {
  'authorization',
  'cookie',
  'set-cookie',
  'x-api-key',
  'x-auth-token',
};

/// Expandable headers section with sensitive-value masking and click-to-copy.
///
/// Shows key-value header rows. Sensitive headers are masked with `●●●●●●●●`
/// and can be revealed per-header on click. Values are click-to-copy.
/// If more than 6 headers, only shows the first 6 with a "+N more" toggle.
class HttpHeadersSection extends StatefulWidget {
  final String title;
  final Map<String, dynamic>? headers;

  const HttpHeadersSection({super.key, required this.title, this.headers});

  @override
  State<HttpHeadersSection> createState() => _HttpHeadersSectionState();
}

class _HttpHeadersSectionState extends State<HttpHeadersSection> {
  final _revealedKeys = <String>{};
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final headers = widget.headers;
    if (headers == null || headers.isEmpty) return const SizedBox.shrink();

    final entries = headers.entries.toList();
    final count = entries.length;
    final visible = _showAll ? entries : entries.take(6).toList();
    final hiddenCount = count - visible.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${widget.title} ($count)',
          style: LoggerTypography.logMeta.copyWith(color: LoggerColors.fgMuted),
        ),
        const SizedBox(height: 2),
        for (final entry in visible)
          _buildHeaderRow(entry.key, '${entry.value}'),
        if (hiddenCount > 0)
          GestureDetector(
            onTap: () => setState(() => _showAll = true),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '+$hiddenCount more',
                  style: LoggerTypography.logMeta.copyWith(
                    color: LoggerColors.fgMuted,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHeaderRow(String key, String value) {
    final isSensitive = _sensitiveHeaders.contains(key.toLowerCase());
    final isRevealed = _revealedKeys.contains(key);
    final displayValue = isSensitive && !isRevealed ? '●●●●●●●●' : value;

    return GestureDetector(
      onTap: () {
        if (isSensitive && !isRevealed) {
          setState(() => _revealedKeys.add(key));
        } else {
          Clipboard.setData(ClipboardData(text: value));
        }
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              key,
              style: LoggerTypography.logMeta.copyWith(
                color: LoggerColors.syntaxKey,
              ),
            ),
            Text(
              ': ',
              style: LoggerTypography.logMeta.copyWith(
                color: LoggerColors.fgMuted,
              ),
            ),
            Flexible(
              child: Text(
                displayValue,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: LoggerTypography.logMeta.copyWith(
                  color: LoggerColors.fgSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
