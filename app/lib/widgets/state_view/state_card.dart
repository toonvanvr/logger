import 'package:flutter/material.dart';

import '../../theme/colors.dart';
import '../../theme/typography.dart';

/// Compact card showing a single state key:value pair.
class StateCard extends StatelessWidget {
  final String stateKey;
  final dynamic stateValue;

  const StateCard({
    super.key,
    required this.stateKey,
    required this.stateValue,
  });

  @override
  Widget build(BuildContext context) {
    final displayValue = stateValue?.toString() ?? 'null';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: LoggerColors.bgSurface,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: LoggerColors.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            stateKey,
            style: LoggerTypography.logMeta.copyWith(
              color: LoggerColors.fgMuted,
              fontSize: 10,
            ),
          ),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 200),
            child: Tooltip(
              message: displayValue,
              child: Text(
                displayValue,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: LoggerTypography.logMeta.copyWith(
                  color: LoggerColors.fgPrimary,
                  fontSize: 10,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
