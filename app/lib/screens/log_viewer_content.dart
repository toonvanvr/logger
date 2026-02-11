part of 'log_viewer.dart';

/// UI/filter state and build helpers for the log viewer layout.
mixin _ContentMixin on State<LogViewerScreen>, _ConnectionMixin {
  String? _selectedSection;
  bool _settingsPanelVisible = false;
  bool _landingDelayActive = true;
  Timer? _landingDelayTimer;

  void _setupQueryStore() {
    final queryStore = context.read<QueryStore>();
    queryStore.onQueryLoaded = (query) {
      context.read<FilterService>().loadQuery(
        severities: Set.from(query.severities),
        textFilter: query.textFilter,
      );
    };
  }

  /// Process launch URI for filter, tab, and clear actions.
  void _handleLaunchUri() {
    final uri = widget.launchUri;
    if (uri == null) return;
    final filterService = context.read<FilterService>();
    UriHandler.handleUri(
      uri,
      connectionManager: context.read<ConnectionManager>(),
      onFilter: (query) => filterService.setTextFilter(query),
      onTab: (name) => setState(() => _selectedSection = name),
      onClear: () => filterService.clear(),
    );
  }

  /// Toggles a state key in/out of the filter stack.
  void _toggleStateFilter(String stateKey) {
    context.read<FilterService>().toggleStateFilter(stateKey);
  }

  /// Header bar: mini title bar or session selector.
  Widget _buildHeader(SettingsService settings) {
    void toggleSettings() =>
        setState(() => _settingsPanelVisible = !_settingsPanelVisible);
    if (settings.miniMode) {
      return MiniTitleBar(onSettingsToggle: toggleSettings);
    }
    return SessionSelector(onRpcToggle: toggleSettings);
  }

  /// Always-visible filter bar (hidden only in mini mode).
  Widget _buildFilterBar() {
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

  /// Content area: landing page or main log content.
  Widget _buildContentArea() {
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
              !_hasEverReceivedEntries &&
              !hasEntries &&
              !hasConnection &&
              !_landingDelayActive;
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
                    onConnect: () {
                      setState(() => _settingsPanelVisible = true);
                    },
                  )
                : _buildMainContent(context),
          );
        },
      ),
    );
  }

  /// Settings panel overlay with scrim backdrop.
  List<Widget> _buildSettingsOverlay(SettingsService settings) {
    final top = settings.miniMode ? 28.0 : 40.0;
    return [
      Positioned(
        left: 0,
        right: 0,
        top: top,
        bottom: 0,
        child: IgnorePointer(
          ignoring: !_settingsPanelVisible,
          child: AnimatedOpacity(
            opacity: _settingsPanelVisible ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: GestureDetector(
              onTap: () => setState(() => _settingsPanelVisible = false),
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
          isVisible: _settingsPanelVisible,
          onClose: () => setState(() => _settingsPanelVisible = false),
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
              selectedTag: _selectedSection,
              onTagChanged: (section) {
                setState(() => _selectedSection = section);
              },
            );
          },
        ),
        StateViewSection(
          onStateFilter: (filter) {
            final key = filter.startsWith('state:')
                ? filter.substring(6)
                : filter;
            _toggleStateFilter(key);
          },
          activeStateFilters: filterService.activeStateFilters,
        ),
        Expanded(
          child: Builder(
            builder: (context) {
              final selectedSessions = context
                  .watch<SessionStore>()
                  .selectedSessionIds;
              final logListView = LogListView(
                tagFilter: _selectedSection,
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
                          onCopy: () => selection.copySelected(logStore.entries),
                          onExportJson: () => selection.exportSelectedJson(logStore.entries),
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
