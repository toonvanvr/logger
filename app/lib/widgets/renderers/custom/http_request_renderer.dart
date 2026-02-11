import 'package:flutter/material.dart';

import '../../../models/log_entry.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import 'http/http_body_section.dart';
import 'http/http_collapsed_row.dart';
import 'http/http_headers_section.dart';
import 'http/http_meta_section.dart';
import 'http/http_timing_bar.dart';

/// Renders an HTTP request/response entry.
///
/// Orchestrates collapsed summary row and expandable detail sections:
/// timing, headers, bodies, and meta. Expand/collapse toggles via chevron.
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        HttpCollapsedRow(
          data: data,
          expanded: _expanded,
          onToggle: () => setState(() => _expanded = !_expanded),
        ),
        if (_expanded)
          AnimatedSize(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            child: _buildExpandedView(data),
          ),
      ],
    );
  }

  Widget _buildExpandedView(Map<String, dynamic> data) {
    final durationMs = (data['duration_ms'] as num?)?.toInt();
    final ttfbMs = (data['ttfb_ms'] as num?)?.toInt();
    final reqHeaders = data['request_headers'] as Map<String, dynamic>?;
    final resHeaders = data['response_headers'] as Map<String, dynamic>?;
    final reqBody = data['request_body'] as String?;
    final resBody = data['response_body'] as String?;
    final reqBodySize = (data['request_body_size'] as num?)?.toInt();
    final resBodySize = (data['response_body_size'] as num?)?.toInt();
    final contentType = data['content_type'] as String?;

    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 4),
      child: Container(
        decoration: const BoxDecoration(
          border: Border(
            left: BorderSide(
              color: LoggerColors.borderSubtle,
              width: 2,
            ),
          ),
        ),
        padding: const EdgeInsets.only(left: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (durationMs != null) ...[
              HttpTimingBar(durationMs: durationMs, ttfbMs: ttfbMs),
              const SizedBox(height: 8),
            ],
            if (reqHeaders != null && reqHeaders.isNotEmpty) ...[
              HttpHeadersSection(
                title: 'Request Headers',
                headers: reqHeaders,
              ),
              const SizedBox(height: 8),
            ],
            if (reqBody != null || reqBodySize != null) ...[
              HttpBodySection(
                title: 'Request Body',
                body: reqBody,
                bodySize: reqBodySize,
                contentType: contentType,
              ),
              const SizedBox(height: 8),
            ],
            if (resHeaders != null && resHeaders.isNotEmpty) ...[
              HttpHeadersSection(
                title: 'Response Headers',
                headers: resHeaders,
              ),
              const SizedBox(height: 8),
            ],
            if (resBody != null || resBodySize != null) ...[
              HttpBodySection(
                title: 'Response Body',
                body: resBody,
                bodySize: resBodySize,
                contentType: contentType,
              ),
              const SizedBox(height: 8),
            ],
            HttpMetaSection(data: data),
          ],
        ),
      ),
    );
  }
}
