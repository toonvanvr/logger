import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/settings_service.dart';
import '../../theme/colors.dart';
import '../../theme/constants.dart';
import '../../theme/typography.dart';
import 'shelf_card.dart';

/// Collapsible secondary shelf for `_shelf.*` state entries.
class SecondaryShelf extends StatelessWidget {
  final Map<String, dynamic> entries;
  final ValueChanged<String>? onStateFilter;

  const SecondaryShelf({
    super.key,
    required this.entries,
    this.onStateFilter,
  });

  @override
  Widget build(BuildContext context) {
    final isCollapsed = context.select<SettingsService, bool>(
      (s) => s.shelfCollapsed,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () =>
              context.read<SettingsService>().setShelfCollapsed(!isCollapsed),
          child: SizedBox(
            height: 20,
            child: Padding(
              padding: kHPadding8,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isCollapsed ? Icons.chevron_right : Icons.expand_more,
                    size: 12,
                    color: LoggerColors.fgMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Secondary',
                    style: LoggerTypography.badge.copyWith(
                      color: LoggerColors.fgMuted,
                      fontSize: kFontSizeLabel,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 3,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: LoggerColors.bgSurface,
                      borderRadius: kBorderRadiusSm,
                    ),
                    child: Text(
                      '${entries.length}',
                      style: LoggerTypography.badge.copyWith(
                        color: LoggerColors.fgMuted,
                        fontSize: kFontSizeBadge,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (!isCollapsed)
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Wrap(
              spacing: 4,
              runSpacing: 3,
              children: entries.entries
                  .map(
                    (e) => ShelfCard(
                      stateKey: e.key,
                      stateValue: e.value,
                      onTap: onStateFilter != null
                          ? () => onStateFilter!('state:${e.key}')
                          : null,
                    ),
                  )
                  .toList(),
            ),
          ),
      ],
    );
  }
}
