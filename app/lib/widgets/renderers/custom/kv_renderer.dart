import 'package:flutter/material.dart';

import '../../../models/log_entry.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';

class KvRenderer extends StatelessWidget {
  final LogEntry entry;

  const KvRenderer({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final data = entry.widget?.data;
    if (data == null) {
      return Text(
        '[kv: invalid data]',
        style: LoggerTypography.logBody.copyWith(color: LoggerColors.fgMuted),
      );
    }

    final entries =
        (data['entries'] as List?)?.map((e) => e as Map).toList() ?? [];
    final layout = data['layout'] as String? ?? 'inline';

    if (entries.isEmpty) {
      return Text(
        '[kv: no entries]',
        style: LoggerTypography.logBody.copyWith(color: LoggerColors.fgMuted),
      );
    }

    if (layout == 'stacked') {
      return _buildStacked(entries);
    }
    return _buildInline(entries);
  }

  Widget _buildInline(List<Map> entries) {
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: entries.map((e) {
        final key = e['key'] as String? ?? '';
        final value = e['value'];
        final colorStr = e['color'] as String?;
        final valueColor = colorStr != null
            ? _parseHex(colorStr)
            : LoggerColors.syntaxNumber;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$key: ',
              style: LoggerTypography.logMeta.copyWith(
                color: LoggerColors.syntaxKey,
              ),
            ),
            Text(
              value?.toString() ?? 'null',
              style: LoggerTypography.logBody.copyWith(color: valueColor),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildStacked(List<Map> entries) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: entries.map((e) {
        final key = e['key'] as String? ?? '';
        final value = e['value'];
        final colorStr = e['color'] as String?;
        final valueColor = colorStr != null
            ? _parseHex(colorStr)
            : LoggerColors.syntaxNumber;

        return Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 120,
                child: Text(
                  key,
                  style: LoggerTypography.logMeta.copyWith(
                    color: LoggerColors.syntaxKey,
                  ),
                ),
              ),
              Flexible(
                child: Text(
                  value?.toString() ?? 'null',
                  style: LoggerTypography.logBody.copyWith(color: valueColor),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  static Color _parseHex(String hex) {
    final clean = hex.replaceFirst('#', '');
    if (clean.length == 6) {
      return Color(int.parse('FF$clean', radix: 16));
    }
    return LoggerColors.syntaxNumber;
  }
}
