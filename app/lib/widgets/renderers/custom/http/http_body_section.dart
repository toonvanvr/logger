import 'package:flutter/material.dart';

import '../../../../theme/colors.dart';
import '../../../../theme/typography.dart';
import 'http_utils.dart';

/// Body preview/full-view section for HTTP request/response bodies.
///
/// Shows a preview of the first 500 chars with a "Show all" toggle.
/// Detects JSON content and applies syntax highlighting. When body is
/// absent but size is known, shows "Body not captured (N KB)".
class HttpBodySection extends StatefulWidget {
  final String title;
  final String? body;
  final int? bodySize;
  final String? contentType;

  const HttpBodySection({
    super.key,
    required this.title,
    this.body,
    this.bodySize,
    this.contentType,
  });

  @override
  State<HttpBodySection> createState() => _HttpBodySectionState();
}

class _HttpBodySectionState extends State<HttpBodySection> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final body = widget.body;
    final size = widget.bodySize;

    // Nothing to show.
    if ((body == null || body.isEmpty) && size == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildTitle(size),
        const SizedBox(height: 2),
        if (body == null || body.isEmpty)
          _buildAbsentBody(size!)
        else
          _buildBodyContent(body),
      ],
    );
  }

  Widget _buildTitle(int? size) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.title,
          style: LoggerTypography.logMeta.copyWith(color: LoggerColors.fgMuted),
        ),
        if (size != null) ...[
          const SizedBox(width: 4),
          Text(
            formatBytes(size),
            style: LoggerTypography.logMeta.copyWith(
              color: LoggerColors.syntaxNumber,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAbsentBody(int size) {
    return Text(
      'Body not captured (${formatBytes(size)})',
      style: LoggerTypography.logMeta.copyWith(color: LoggerColors.fgMuted),
    );
  }

  Widget _buildBodyContent(String body) {
    final isJson = _isJsonContent(body, widget.contentType);
    final preview = body.length > 500 && !_showAll;
    final displayText = preview ? '${body.substring(0, 500)}…' : body;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 300),
          child: SingleChildScrollView(
            child: SelectionArea(
              child: Text(
                displayText,
                style: LoggerTypography.logMeta.copyWith(
                  color: isJson
                      ? LoggerColors.syntaxString
                      : LoggerColors.fgSecondary,
                ),
              ),
            ),
          ),
        ),
        if (preview)
          GestureDetector(
            onTap: () => setState(() => _showAll = true),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  'Show all (${formatBytes(body.length)})',
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

  bool _isJsonContent(String body, String? contentType) {
    if (contentType != null && contentType.contains('json')) return true;
    final trimmed = body.trimLeft();
    return trimmed.startsWith('{') || trimmed.startsWith('[');
  }
}
