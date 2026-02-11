import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/connection_manager.dart';
import '../services/filter_service.dart';
import '../services/log_store.dart';
import '../services/selection_service.dart';
import '../services/session_store.dart';
import '../services/settings_service.dart';
import '../widgets/header/filter_bar.dart';
import '../widgets/header/session_selector.dart';
import '../widgets/landing/empty_landing_page.dart';
import '../widgets/log_list/log_list_view.dart';
import '../widgets/log_list/section_tabs.dart';
import '../widgets/log_list/selection_actions.dart';
import '../widgets/mini_mode/mini_title_bar.dart';
import '../widgets/settings/settings_panel.dart';
import '../widgets/state_view/state_view_section.dart';
import '../widgets/status_bar/status_bar.dart';
import '../widgets/time_travel/time_range_minimap.dart';

/// Stateless build logic for the log viewer screen.
///
/// Local UI state is managed by [LogViewerScreen] and passed via callbacks.
class LogViewerBody extends StatelessWidget {
  final String? selectedSection;
  final bool settingsPanelVisible;
  final bool hasEverReceivedEntries;
  final bool landingDelayActive;
  final ValueChanged<String?> onSectionChanged;
  final VoidCallback onSettingsToggle;
  final VoidCallback onSettingsClose;
  final VoidCallback onSettingsOpen;

  const LogViewerBody({
    super.key,
    required this.selectedSection,
    required this.settingsPanelVisible,
    required this.hasEverReceivedEntries,
    required this.landingDelayActive,
    required this.onSectionChanged,
    required this.onSettingsToggle,
    required this.onSettingsClose,
    required this.onSettingsOpen,
  });

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              _buildHeader(settings),
              _buildFilterBar(context),
              _buildContentArea(context),
              const StatusBar(),
            ],
          ),
          ..._buildSettingsOverlay(settings),
        ],
      ),
    );
  }

  Widget _buildHeader(SettingsService settings) {
    if (settings.miniMode) {
      return MiniTitleBar(onSettingsToggle: onSettingsToggle);
    }
    return SessionSelector(onRpcToggle: onSettingsToggle);
  }

  Widget _buildFilterBar(BuildContext context) {
    final settings = context.watch<SettingsService>();
    if (settings.miniMode) return const SizedBox.shrink();

    final filterService = context.watch<FilterService>();
    return FilterBar(
      activeSeverities: filterService.activeSeverities,
      onSeverityChange: (s) => filterService.setSeverities(s),
      onTextFilterChange: (t) => filterService.setTextFilter(t),
      onClear: () => filterService.clear(),
      activeStateFilters: filterService.activeStateFilters,
      onStateFilterRemove: (key) => filterService.removeStateFilter(key),
      flatMode: filterService.flatMode,
      onFlatModeToggle: (v) => filterService.setFlatMode(v),
    );
  }

  Widget _buildContentArea(BuildContext context) {
    return Expanded(
      child: Builder(
        builder: (context) {
          final hasEntries = context.select<LogStore, bool>(
            (s) => s.entries.isNotEmpty,
          );
          final hasConnection = context.select<ConnectionManager, bool>(
            (c) => c.activeCount > 0,
          );
          final showLanding =
              !hasEverReceivedEntries &&
              !hasEntries &&
              !hasConnection &&
              !landingDelayActive;
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            layoutBuilder: (currentChild, previousChildren) {
              return Stack(
                alignment: Alignment.center,
                children: <Widget>[...previousChildren, ?currentChild],
              );
            },
            child: showLanding
                ? EmptyLandingPage(
                    key: const ValueKey('landing'),
                    onConnect: onSettingsOpen,
                  )
                : _buildMainContent(context),
          );
        },
      ),
    );
  }

  List<Widget> _buildSettingsOverlay(SettingsService settings) {
    final top = settings.miniMode ? 28.0 : 40.0;
    return [
      Positioned(
        left: 0,
        right: 0,
        top: top,
        bottom: 0,
        child: IgnorePointer(
          ignoring: !settingsPanelVisible,
          child: AnimatedOpacity(
            opacity: settingsPanelVisible ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: GestureDetector(
              onTap: onSettingsClose,
              child: const ColoredBox(color: Color(0x40000000)),
            ),
          ),
        ),
      ),
      Positioned(
        right: 0,
        top: top,
        bottom: 0,
        child: SettingsPanel(
          isVisible: settingsPanelVisible,
          onClose: onSettingsClose,
        ),
      ),
    ];
  }

  Widget _buildMainContent(BuildContext context) {
    final filterService = context.watch<FilterService>();
    final selection = context.watch<SelectionService>();
    return Column(
      key: const ValueKey('content'),
      children: [
        Builder(
          builder: (context) {
            final logStore = context.watch<LogStore>();
            final sections = <String>{
              for (final e in logStore.entries) ?e.tag,
            }.toList()..sort();
            return SectionTabs(
              tags: sections,
              selectedTag: selectedSection,
              onTagChanged: onSectionChanged,
            );
          },
        ),
        StateViewSection(
          onStateFilter: (filter) {
            final key =
                filter.startsWith('state:') ? filter.substring(6) : filter;
            context.read<FilterService>().toggleStateFilter(key);
          },
          activeStateFilters: filterService.activeStateFilters,
        ),
        Expanded(
          child: Builder(
            builder: (context) {
              final selectedSessions =
                  context.watch<SessionStore>().selectedSessionIds;
              final logListView = LogListView(
                tagFilter: selectedSection,
                activeSeverities: filterService.activeSeverities,
                textFilter: filterService.effectiveFilter,
                selectedSessionIds: selectedSessions,
                selectionMode: selection.selectionMode,
                selectedEntryIds: selection.selectedEntryIds,
                onEntrySelected: selection.onEntrySelected,
                onEntryRangeSelected: selection.onEntryRangeSelected,
                bookmarkedEntryIds: selection.bookmarkedEntryIds,
                stickyOverrideIds: selection.stickyOverrideIds,
                flatMode: filterService.flatMode,
                onFilterClear: () => filterService.clear(),
              );
              final logStore = context.read<LogStore>();
              return Stack(
                children: [
                  selection.selectionMode
                      ? logListView
                      : SelectionArea(child: logListView),
                  if (selection.selectedEntryIds.isNotEmpty)
                    Positioned(
                      bottom: 12,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: SelectionActions(
                          selectedCount: selection.selectedEntryIds.length,
                          onCopy: () =>
                              selection.copySelected(logStore.entries),
                          onExportJson: () =>
                              selection.exportSelectedJson(logStore.entries),
                          onBookmark: selection.bookmarkSelected,
                          onSticky: selection.stickySelected,
                          onClear: selection.clearSelection,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        const TimeRangeMinimap(),
      ],
    );
  }
}
