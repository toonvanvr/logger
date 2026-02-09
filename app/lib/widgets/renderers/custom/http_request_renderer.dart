import 'package:flutter/material.dart';

import '../../../models/log_entry.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';

/// Renders an HTTP request/response entry.
///
/// Summary row: `[METHOD] URL → STATUS (duration_ms ms)` with color-coded
/// status. Expandable sections for headers and body.
class HttpRequestRenderer extends StatefulWidget {
  final LogEntry entry;

  const HttpRequestRenderer({super.key, required this.entry});

  @override
  State<HttpRequestRenderer> createState() => _HttpRequestRendererState();
}

class _HttpRequestRendererState extends State<HttpRequestRenderer> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final data = widget.entry.widget?.data;
    if (data == null) {
      return Text(
        '[http_request: invalid data]',
        style: LoggerTypography.logBody.copyWith(color: LoggerColors.fgMuted),
      );
    }

    final method = data['method'] as String? ?? '?';
    final url = data['url'] as String? ?? '';
    final status = data['status'] as num?;
    final durationMs = data['duration_ms'] as num?;
    final isError = data['is_error'] == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildSummary(method, url, status, durationMs, isError),
        if (_expanded) ...[const SizedBox(height: 4), _buildDetails(data)],
      ],
    );
  }

  Widget _buildSummary(
    String method,
    String url,
    num? status,
    num? durationMs,
    bool isError,
  ) {
    final statusColor = _statusColor(status, isError);
    final methodColor = method == 'GET'
        ? LoggerColors.syntaxKey
        : LoggerColors.syntaxString;

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _expanded ? Icons.expand_more : Icons.chevron_right,
              size: 14,
              color: LoggerColors.fgMuted,
            ),
            const SizedBox(width: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: methodColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                method,
                style: LoggerTypography.logMeta.copyWith(
                  color: methodColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                url,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: LoggerTypography.logBody.copyWith(
                  color: LoggerColors.fgPrimary,
                ),
              ),
            ),
            if (status != null) ...[
              const SizedBox(width: 6),
              Text(
                '→',
                style: LoggerTypography.logBody.copyWith(
                  color: LoggerColors.fgMuted,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '$status',
                style: LoggerTypography.logMeta.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (durationMs != null) ...[
              const SizedBox(width: 6),
              Text(
                '${durationMs}ms',
                style: LoggerTypography.logMeta.copyWith(
                  color: LoggerColors.fgMuted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetails(Map data) {
    final reqHeaders = data['request_headers'] as Map?;
    final resHeaders = data['response_headers'] as Map?;
    final reqBody = data['request_body'] as String?;
    final resBody = data['response_body'] as String?;

    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (reqHeaders != null && reqHeaders.isNotEmpty)
            _buildHeaderSection('Request Headers', reqHeaders),
          if (resHeaders != null && resHeaders.isNotEmpty)
            _buildHeaderSection('Response Headers', resHeaders),
          if (reqBody != null && reqBody.isNotEmpty)
            _buildBodySection('Request Body', reqBody),
          if (resBody != null && resBody.isNotEmpty)
            _buildBodySection('Response Body', resBody),
        ],
      ),
    );
  }

  Widget _buildHeaderSection(String title, Map headers) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: LoggerTypography.logMeta.copyWith(
              color: LoggerColors.fgMuted,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          ...headers.entries.map(
            (e) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${e.key}: ',
                  style: LoggerTypography.logMeta.copyWith(
                    color: LoggerColors.syntaxKey,
                  ),
                ),
                Flexible(
                  child: Text(
                    '${e.value}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: LoggerTypography.logBody.copyWith(
                      color: LoggerColors.fgSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBodySection(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: LoggerTypography.logMeta.copyWith(
              color: LoggerColors.fgMuted,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: LoggerColors.bgSurface,
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              body.length > 500 ? '${body.substring(0, 500)}…' : body,
              style: LoggerTypography.logBody.copyWith(
                color: LoggerColors.fgSecondary,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Color _statusColor(num? status, bool isError) {
    if (isError || (status != null && status >= 500)) {
      return LoggerColors.severityErrorText;
    }
    if (status != null && status >= 400) {
      return LoggerColors.severityWarningText;
    }
    if (status != null && status >= 200 && status < 300) {
      return LoggerColors.severityInfoText;
    }
    return LoggerColors.fgMuted;
  }
}
