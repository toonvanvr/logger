import 'package:flutter/material.dart';

import '../../theme/colors.dart';
import '../../theme/typography.dart';

/// Small "LIVE" pill shown when auto-scroll is active.
class LivePill extends StatelessWidget {
  const LivePill({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: LoggerColors.bgOverlay.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '⬇',
            style: TextStyle(fontSize: 8, color: LoggerColors.fgMuted),
          ),
          const SizedBox(width: 3),
          Text(
            'LIVE',
            style: LoggerTypography.badge.copyWith(color: LoggerColors.fgMuted),
          ),
        ],
      ),
    );
  }
}

/// Button showing count of new unseen logs. Tap to resume auto-scroll.
class NewLogsButton extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const NewLogsButton({super.key, required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: LoggerColors.bgOverlay,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '⬇',
              style: TextStyle(fontSize: 8, color: LoggerColors.syntaxNumber),
            ),
            const SizedBox(width: 3),
            Text(
              '$count new',
              style: LoggerTypography.badge.copyWith(
                color: LoggerColors.syntaxNumber,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
