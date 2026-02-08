import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/log_store.dart';
import '../../services/settings_service.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';
import 'state_card.dart';

/// Collapsible section showing persistent state key-value pairs.
/// Placed between SectionTabs and LogListView.
class StateViewSection extends StatelessWidget {
  const StateViewSection({super.key});

  @override
  Widget build(BuildContext context) {
    final logStore = context.watch<LogStore>();
    final settings = context.watch<SettingsService>();
    final state = logStore.mergedState;

    if (state.isEmpty) return const SizedBox.shrink();

    final isCollapsed = settings.stateViewCollapsed;

    return Container(
      decoration: BoxDecoration(
        color: LoggerColors.bgRaised,
        border: const Border(
          bottom: BorderSide(color: LoggerColors.borderSubtle),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header row
          GestureDetector(
            onTap: () => settings.setStateViewCollapsed(!isCollapsed),
            child: Container(
              height: 24,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  Icon(
                    isCollapsed ? Icons.chevron_right : Icons.expand_more,
                    size: 14,
                    color: LoggerColors.fgMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'State',
                    style: LoggerTypography.headerBtn.copyWith(
                      color: LoggerColors.fgSecondary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: LoggerColors.bgSurface,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      '${state.length}',
                      style: LoggerTypography.badge.copyWith(
                        color: LoggerColors.fgMuted,
                        fontSize: 9,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Card grid
          if (!isCollapsed)
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.3,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: state.entries
                      .map(
                        (entry) => StateCard(
                          stateKey: entry.key,
                          stateValue: entry.value,
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
