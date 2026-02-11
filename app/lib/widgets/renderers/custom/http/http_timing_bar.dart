import 'package:flutter/material.dart';

import '../../../../theme/colors.dart';
import '../../../../theme/constants.dart';
import '../../../../theme/typography.dart';
import 'http_utils.dart';

/// Proportional timing bar showing TTFB and transfer segments.
///
/// Full-width bar (8dp height) with optional TTFB/transfer breakdown.
/// If [ttfbMs] is absent, renders a single solid bar.
class HttpTimingBar extends StatelessWidget {
  final int? durationMs;
  final int? ttfbMs;

  const HttpTimingBar({super.key, this.durationMs, this.ttfbMs});

  @override
  Widget build(BuildContext context) {
    final duration = durationMs;
    if (duration == null || duration <= 0) return const SizedBox.shrink();

    final ttfb = ttfbMs;
    final hasTtfb = ttfb != null && ttfb > 0 && ttfb < duration;
    final ttfbFraction = hasTtfb ? ttfb / duration : 1.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: kBorderRadiusSm,
                child: SizedBox(
                  height: 8,
                  child: Row(
                    children: [
                      Expanded(
                        flex: (ttfbFraction * 100).round(),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          color: LoggerColors.syntaxKey,
                        ),
                      ),
                      if (hasTtfb)
                        Expanded(
                          flex: ((1 - ttfbFraction) * 100).round(),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            color: LoggerColors.syntaxKey.withValues(
                              alpha: 0.30,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '${duration}ms',
              style: LoggerTypography.logMeta.copyWith(
                color: durationColor(duration),
              ),
            ),
          ],
        ),
        if (hasTtfb) ...[
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${ttfb}ms (${(ttfbFraction * 100).round()}%)',
                style: LoggerTypography.logMeta.copyWith(
                  color: LoggerColors.fgSecondary,
                ),
              ),
              Text(
                '${duration - ttfb}ms '
                '(${((1 - ttfbFraction) * 100).round()}%)',
                style: LoggerTypography.logMeta.copyWith(
                  color: LoggerColors.fgSecondary,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
