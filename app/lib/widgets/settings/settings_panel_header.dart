import 'package:flutter/material.dart';

import '../../theme/colors.dart';
import '../../theme/constants.dart';
import '../../theme/typography.dart';

/// Panel header with optional back button for the settings sidebar.
class SettingsPanelHeader extends StatelessWidget {
  final String title;
  final bool showBack;
  final VoidCallback onBack;
  final VoidCallback onClose;

  const SettingsPanelHeader({
    super.key,
    required this.title,
    required this.showBack,
    required this.onBack,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: kHPadding12,
      child: Row(
        children: [
          if (showBack)
            InkWell(
              onTap: onBack,
              child: const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(
                  Icons.arrow_back,
                  size: 16,
                  color: LoggerColors.fgSecondary,
                ),
              ),
            ),
          Text(title, style: LoggerTypography.sectionH),
          const Spacer(),
          InkWell(
            onTap: onClose,
            child: const Icon(
              Icons.close,
              size: 16,
              color: LoggerColors.fgSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
