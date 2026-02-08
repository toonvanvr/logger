import 'package:flutter/material.dart';

import '../../theme/colors.dart';
import '../../theme/typography.dart';

/// Dimmed card variant for secondary state (_shelf.* prefix keys).
///
/// Visual distinction from primary [StateCard]: fgMuted key, fgSecondary
/// value, 60% opacity background, left accent border.
class ShelfCard extends StatelessWidget {
  final String stateKey;
  final dynamic stateValue;
  final VoidCallback? onTap;

  const ShelfCard({
    super.key,
    required this.stateKey,
    required this.stateValue,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final displayKey = stateKey.replaceFirst('_shelf.', '');
    final displayValue = stateValue?.toString() ?? 'null';
    final truncated = displayValue.length > 120
        ? '${displayValue.substring(0, 120)}…'
        : displayValue;

    return MouseRegion(
      cursor: onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          decoration: BoxDecoration(
            color: LoggerColors.bgSurface.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(3),
            border: const Border(
              left: BorderSide(color: LoggerColors.borderSubtle, width: 2),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                displayKey,
                style: LoggerTypography.logMeta.copyWith(
                  color: LoggerColors.fgMuted,
                  fontSize: 9,
                ),
              ),
              const SizedBox(width: 4),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 200),
                child: Tooltip(
                  message: displayValue,
                  child: Text(
                    truncated,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: LoggerTypography.logMeta.copyWith(
                      color: LoggerColors.fgSecondary,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
