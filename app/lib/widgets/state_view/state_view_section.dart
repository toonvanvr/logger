import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/log_store.dart';
import '../../services/settings_service.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';
import 'secondary_shelf.dart';
import 'state_card.dart';
import 'state_chart_strip.dart';

/// Collapsible section showing persistent state key-value pairs.
/// Placed between SectionTabs and LogListView.
class StateViewSection extends StatelessWidget {
  final ValueChanged<String>? onStateFilter;
  final Set<String> activeStateFilters;

  const StateViewSection({
    super.key,
    this.onStateFilter,
    this.activeStateFilters = const {},
  });

  @override
  Widget build(BuildContext context) {
    final logStore = context.watch<LogStore>();
    final isCollapsed = context.select<SettingsService, bool>(
      (s) => s.stateViewCollapsed,
    );
    final state = logStore.mergedState;

    if (state.isEmpty) return const SizedBox.shrink();

    final chartEntries = <String, dynamic>{};
    final shelfEntries = <String, dynamic>{};
    final displayEntries = <String, dynamic>{};
    for (final entry in state.entries) {
      if (entry.key.startsWith('_chart.')) {
        chartEntries[entry.key] = entry.value;
      } else if (entry.key.startsWith('_shelf.')) {
        shelfEntries[entry.key] = entry.value;
      } else {
        displayEntries[entry.key] = entry.value;
      }
    }

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
          GestureDetector(
            onTap: () => context.read<SettingsService>().setStateViewCollapsed(
              !isCollapsed,
            ),
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
                      '${displayEntries.length}',
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
          if (!isCollapsed)
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.3,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (displayEntries.isNotEmpty)
                      displayEntries.length >= 4
                          ? LayoutBuilder(
                              builder: (context, constraints) {
                                final columns = (constraints.maxWidth / 186)
                                    .floor()
                                    .clamp(2, 6);
                                final cellWidth =
                                    (constraints.maxWidth - (columns - 1) * 6) /
                                    columns;
                                return GridView.count(
                                  crossAxisCount: columns,
                                  mainAxisSpacing: 4,
                                  crossAxisSpacing: 6,
                                  childAspectRatio: cellWidth / 26,
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  children: displayEntries.entries
                                      .map(
                                        (entry) => StateCard(
                                          stateKey: entry.key,
                                          stateValue: entry.value,
                                          fixedWidth: true,
                                          isActiveFilter: activeStateFilters
                                              .contains(entry.key),
                                          onTap: onStateFilter != null
                                              ? () => onStateFilter!(
                                                  'state:${entry.key}',
                                                )
                                              : null,
                                        ),
                                      )
                                      .toList(),
                                );
                              },
                            )
                          : Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: displayEntries.entries
                                  .map(
                                    (entry) => StateCard(
                                      stateKey: entry.key,
                                      stateValue: entry.value,
                                      isActiveFilter: activeStateFilters
                                          .contains(entry.key),
                                      onTap: onStateFilter != null
                                          ? () => onStateFilter!(
                                              'state:${entry.key}',
                                            )
                                          : null,
                                    ),
                                  )
                                  .toList(),
                            ),
                    if (chartEntries.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      StateChartStrip(
                        chartEntries: chartEntries,
                        onTap: onStateFilter != null
                            ? (key) => onStateFilter!('state:_chart.$key')
                            : null,
                      ),
                    ],
                    if (shelfEntries.isNotEmpty)
                      SecondaryShelf(
                        entries: shelfEntries,
                        onStateFilter: onStateFilter,
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
