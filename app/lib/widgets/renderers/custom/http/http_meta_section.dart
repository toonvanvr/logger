import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../theme/colors.dart';
import '../../../../theme/constants.dart';
import '../../../../theme/typography.dart';
import 'http_utils.dart';

/// Compact row of meta key-value pairs for an HTTP entry.
///
/// Shows request_id (copiable badge), content_type, started_at timestamp,
/// and request/response body sizes with directional arrows.
class HttpMetaSection extends StatelessWidget {
  final Map<String, dynamic> data;

  const HttpMetaSection({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final requestId = data['request_id'] as String?;
    final contentType = data['content_type'] as String?;
    final startedAt = data['started_at'] as String?;
    final reqSize = (data['request_body_size'] as num?)?.toInt();
    final resSize = (data['response_body_size'] as num?)?.toInt();

    final items = <Widget>[];
    if (requestId != null) items.add(_copiableBadge(requestId));
    if (contentType != null) items.add(_textItem(contentType));
    if (startedAt != null) items.add(_textItem(_formatTimestamp(startedAt)));
    if (reqSize != null) {
      items.add(_coloredItem('↑ ${formatBytes(reqSize)}'));
    }
    if (resSize != null) {
      items.add(_coloredItem('↓ ${formatBytes(resSize)}'));
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Wrap(spacing: 8, runSpacing: 4, children: items);
  }

  Widget _copiableBadge(String value) {
    return GestureDetector(
      onTap: () => Clipboard.setData(ClipboardData(text: value)),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: LoggerColors.bgOverlay,
            borderRadius: kBorderRadiusSm,
          ),
          child: Text(
            value,
            style: LoggerTypography.logMeta.copyWith(
              color: LoggerColors.fgSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _textItem(String text) {
    return Text(
      text,
      style: LoggerTypography.logMeta.copyWith(color: LoggerColors.fgSecondary),
    );
  }

  Widget _coloredItem(String text) {
    return Text(
      text,
      style: LoggerTypography.logMeta.copyWith(
        color: LoggerColors.syntaxNumber,
      ),
    );
  }

  String _formatTimestamp(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    return '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}:'
        '${dt.second.toString().padLeft(2, '0')}.'
        '${dt.millisecond.toString().padLeft(3, '0')}';
  }
}
