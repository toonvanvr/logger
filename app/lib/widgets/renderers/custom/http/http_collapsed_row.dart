import 'package:flutter/material.dart';

import '../../../../theme/colors.dart';
import '../../../../theme/typography.dart';
import 'http_utils.dart';

/// Collapsed single-line summary row for an HTTP request entry.
///
/// Layout: `[Chevron] [MethodPill] [URL(flex)] [→] [StatusPill] [Duration]`
/// When the request is an error or status >= 500, a second error hint
/// row is displayed below with the first line of the response body.
class HttpCollapsedRow extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool expanded;
  final VoidCallback onToggle;

  const HttpCollapsedRow({
    super.key,
    required this.data,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final method = data['method'] as String? ?? '?';
    final url = data['url'] as String? ?? '';
    final status = (data['status'] as num?)?.toInt();
    final durationMs = (data['duration_ms'] as num?)?.toInt();
    final isError = data['is_error'] == true;
    final statusText = data['status_text'] as String?;
    final responseBody = data['response_body'] as String?;

    final showErrorHint =
        (isError || (status != null && status >= 500)) &&
        responseBody != null &&
        responseBody.isNotEmpty;

    final (statusColor, statusLabel) = classifyStatus(
      status,
      isError,
      statusText: statusText,
    );
    final mColor = methodColor(method);
    final dColor = durationColor(durationMs);
    final parsed = parseUrl(url);

    return InkWell(
      onTap: onToggle,
      child: Container(
        decoration: showErrorHint
            ? const BoxDecoration(
                color: Color(0x15E06C60), // severityErrorBg
              )
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 28,
              child: Row(
                children: [
                  Icon(
                    expanded ? Icons.expand_more : Icons.chevron_right,
                    size: 14,
                    color: LoggerColors.fgMuted,
                  ),
                  const SizedBox(width: 4),
                  _methodPill(method, mColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      decodeUrlForDisplay(parsed.path),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: LoggerTypography.logBody.copyWith(
                        color: LoggerColors.fgPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '→',
                    style: LoggerTypography.logBody.copyWith(
                      color: LoggerColors.fgMuted,
                    ),
                  ),
                  const SizedBox(width: 4),
                  SizedBox(
                    width: 80,
                    child: Text(
                      statusLabel,
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: LoggerTypography.logMeta.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 64,
                    child: Text(
                      _formatDuration(durationMs),
                      textAlign: TextAlign.right,
                      style: LoggerTypography.logMeta.copyWith(color: dColor),
                    ),
                  ),
                ],
              ),
            ),
            if (showErrorHint) _buildErrorHint(responseBody),
          ],
        ),
      ),
    );
  }

  Widget _methodPill(String method, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        method,
        style: LoggerTypography.logMeta.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildErrorHint(String responseBody) {
    final firstLine = responseBody.split('\n').first;
    final truncated = firstLine.length > 120
        ? '${firstLine.substring(0, 120)}…'
        : firstLine;

    return Padding(
      padding: const EdgeInsets.only(left: 18, bottom: 2),
      child: Text(
        truncated,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: LoggerTypography.logMeta.copyWith(
          color: LoggerColors.fgSecondary,
        ),
      ),
    );
  }

  String _formatDuration(int? ms) {
    if (ms == null) return '—';
    if (ms >= 1000) return '${(ms / 1000).toStringAsFixed(1)}s';
    return '${ms}ms';
  }
}
