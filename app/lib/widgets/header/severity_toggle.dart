import 'package:flutter/material.dart';

import '../../theme/colors.dart';
import '../../theme/typography.dart';

/// Single-letter severity toggle button used in the filter bar.
class SeverityToggle extends StatelessWidget {
  final String severity;
  final bool isActive;
  final VoidCallback onToggle;

  const SeverityToggle({
    super.key,
    required this.severity,
    required this.isActive,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final color = severityBarColor(severity);

    return GestureDetector(
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: isActive ? color.withAlpha(51) : Colors.transparent,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: isActive ? color : LoggerColors.borderDefault,
            width: 1,
          ),
        ),
        child: Text(
          severity[0].toUpperCase(),
          style: LoggerTypography.badge.copyWith(
            color: isActive ? color : LoggerColors.fgMuted,
          ),
        ),
      ),
    );
  }
}
