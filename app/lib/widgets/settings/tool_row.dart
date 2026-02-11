import 'package:flutter/material.dart';

import '../../theme/colors.dart';
import '../../theme/constants.dart';
import '../../theme/typography.dart';

/// A single tool entry in a [ToolGroup]: icon + label + optional checkbox
/// + optional chevron for config.
class ToolRow extends StatelessWidget {
  final IconData icon;
  final String label;

  /// If non-null, a checkbox is shown. Null = not disableable.
  final bool? enabled;
  final ValueChanged<bool>? onEnabledChanged;

  /// Whether to show a chevron for config sub-panel.
  final bool hasConfig;
  final VoidCallback? onConfigTap;

  const ToolRow({
    super.key,
    required this.icon,
    required this.label,
    this.enabled,
    this.onEnabledChanged,
    this.hasConfig = false,
    this.onConfigTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      child: Padding(
        padding: kHPadding12,
        child: Row(
          children: [
            Icon(icon, size: 14, color: LoggerColors.fgMuted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: LoggerTypography.drawer.copyWith(
                  color: LoggerColors.fgSecondary,
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (enabled != null)
              SizedBox(
                width: 18,
                height: 18,
                child: Checkbox(
                  value: enabled,
                  onChanged: (v) => onEnabledChanged?.call(v ?? false),
                  activeColor: LoggerColors.borderFocus,
                  side: const BorderSide(color: LoggerColors.fgMuted),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            if (hasConfig)
              GestureDetector(
                onTap: onConfigTap,
                child: const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: LoggerColors.fgMuted,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
