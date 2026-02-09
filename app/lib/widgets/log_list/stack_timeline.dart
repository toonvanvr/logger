import 'package:flutter/material.dart';

import '../../theme/colors.dart';
import '../../theme/typography.dart';

/// Horizontal dot scrubber for navigating stack versions.
///
/// Shows individual dots for ≤20 versions, condensed slider for more.
class StackTimeline extends StatelessWidget {
  final int count;
  final int activeIndex;
  final ValueChanged<int>? onSelect;

  const StackTimeline({
    super.key,
    required this.count,
    required this.activeIndex,
    this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();

    if (count > 20) return _buildCondensed();

    return SizedBox(
      height: 24,
      child: Row(
        children: List.generate(count, (i) {
          final isActive = i == activeIndex;
          return GestureDetector(
            onTap: () => onSelect?.call(i),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Container(
                width: isActive ? 8 : 6,
                height: isActive ? 8 : 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive
                      ? LoggerColors.borderFocus
                      : LoggerColors.fgMuted,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCondensed() {
    return SizedBox(
      height: 24,
      child: Row(
        children: [
          Text('1', style: LoggerTypography.logMeta),
          const SizedBox(width: 4),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
                activeTrackColor: LoggerColors.borderFocus,
                inactiveTrackColor: LoggerColors.fgMuted.withValues(alpha: 0.3),
                thumbColor: LoggerColors.borderFocus,
                overlayShape: SliderComponentShape.noOverlay,
              ),
              child: Slider(
                min: 0,
                max: (count - 1).toDouble(),
                value: activeIndex.toDouble().clamp(0, (count - 1).toDouble()),
                onChanged: (v) => onSelect?.call(v.round()),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Text('$count', style: LoggerTypography.logMeta),
        ],
      ),
    );
  }
}
