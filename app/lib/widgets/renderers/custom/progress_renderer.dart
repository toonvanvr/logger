import 'package:flutter/material.dart';

import '../../../models/log_entry.dart';
import '../../../theme/colors.dart';
import '../../../theme/constants.dart';
import '../../../theme/typography.dart';

class ProgressRenderer extends StatelessWidget {
  final LogEntry entry;

  const ProgressRenderer({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final data = entry.widget?.data;
    if (data == null) {
      return Text(
        '[progress: invalid data]',
        style: LoggerTypography.logBody.copyWith(color: LoggerColors.fgMuted),
      );
    }

    final value = (data['value'] as num?)?.toDouble() ?? 0;
    final max = (data['max'] as num?)?.toDouble() ?? 100;
    final label = data['label'] as String?;
    final sublabel = data['sublabel'] as String?;
    final colorStr = data['color'] as String?;
    final style = data['style'] as String? ?? 'bar';

    final progress = max > 0 ? (value / max).clamp(0.0, 1.0) : 0.0;
    final percentage = (progress * 100).round();

    final color = colorStr != null
        ? _parseHex(colorStr)
        : LoggerColors.borderFocus;

    if (style == 'ring') {
      return _buildRing(progress, percentage, color, label, sublabel);
    }

    return _buildBar(progress, percentage, color, label, sublabel);
  }

  Widget _buildBar(
    double progress,
    int percentage,
    Color color,
    String? label,
    String? sublabel,
  ) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400, minHeight: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 24,
            decoration: BoxDecoration(
              color: LoggerColors.bgOverlay,
              borderRadius: kBorderRadius,
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                FractionallySizedBox(
                  widthFactor: progress,
                  child: Container(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: kBorderRadius,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Padding(
                    padding: kHPadding8,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (label != null)
                          Flexible(
                            child: Text(
                              label,
                              style: LoggerTypography.logMeta.copyWith(
                                color: LoggerColors.fgPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        Text(
                          '$percentage%',
                          style: LoggerTypography.logMeta.copyWith(
                            color: LoggerColors.fgPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (sublabel != null) ...[
            const SizedBox(height: 2),
            Text(
              sublabel,
              style: LoggerTypography.logMeta.copyWith(
                color: LoggerColors.fgMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRing(
    double progress,
    int percentage,
    Color color,
    String? label,
    String? sublabel,
  ) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400, minHeight: 28),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  color: color,
                  backgroundColor: LoggerColors.bgOverlay,
                  strokeWidth: 4,
                ),
                Text(
                  '$percentage%',
                  style: LoggerTypography.logMeta.copyWith(
                    color: LoggerColors.fgPrimary,
                  ),
                ),
              ],
            ),
          ),
          if (label != null || sublabel != null) ...[
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (label != null) Text(label, style: LoggerTypography.logBody),
                if (sublabel != null)
                  Text(
                    sublabel,
                    style: LoggerTypography.logMeta.copyWith(
                      color: LoggerColors.fgMuted,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static Color _parseHex(String hex) {
    final clean = hex.replaceFirst('#', '');
    if (clean.length == 6) {
      return Color(int.parse('FF$clean', radix: 16));
    }
    return LoggerColors.severityInfoBar;
  }
}
