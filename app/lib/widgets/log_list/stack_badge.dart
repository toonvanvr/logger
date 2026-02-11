import 'package:flutter/material.dart';

import '../../theme/colors.dart';
import '../../theme/constants.dart';
import '../../theme/typography.dart';

/// Pill badge showing the stack depth (×N) for stacked log entries.
class StackBadge extends StatelessWidget {
  final int depth;
  final VoidCallback? onTap;

  const StackBadge({super.key, required this.depth, this.onTap});

  @override
  Widget build(BuildContext context) {
    if (depth <= 1) return const SizedBox.shrink();

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
        margin: const EdgeInsets.only(left: 4),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        constraints: const BoxConstraints(minWidth: 16, minHeight: 14),
        decoration: BoxDecoration(
          color: LoggerColors.borderFocus.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          '×$depth',
          style: LoggerTypography.logBody.copyWith(
            fontSize: kFontSizeBody,
            color: LoggerColors.fgSecondary,
          ),
        ),
      ),
      ),
    );
  }
}
