part of 'log_viewer.dart';

/// Build helpers for the log viewer layout.
mixin _ContentMixin on _KeyboardMixin, _SelectionMixin, _ConnectionMixin {
  /// Header bar: mini title bar or session selector.
  Widget _buildHeader(SettingsService settings) {
    void toggleFilter() =>
        setState(() => _isFilterExpanded = !_isFilterExpanded);
    void toggleSettings() =>
        setState(() => _settingsPanelVisible = !_settingsPanelVisible);
    if (settings.miniMode) {
      return MiniTitleBar(
        isFilterExpanded: _isFilterExpanded,
        onFilterToggle: toggleFilter,
        onSettingsToggle: toggleSettings,
      );
    }
    return SessionSelector(
      isFilterExpanded: _isFilterExpanded,
      onFilterToggle: toggleFilter,
      onRpcToggle: toggleSettings,
    );
  }

  /// Animated filter bar.
  Widget _buildFilterBar() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: _isFilterExpanded
          ? FilterBar(
              activeSeverities: _activeSeverities,
              onSeverityChange: (s) => setState(() => _activeSeverities = s),
              onTextFilterChange: (t) => setState(() => _textFilter = t),
              onClear: () {
                setState(() {
                  _activeSeverities = _defaultSeverities;
                  _textFilter = '';
                  _stateFilterStack = [];
                });
              },
              activeStateFilters: _stateFilterStack.toSet(),
              onStateFilterRemove: (key) {
                _toggleStateFilter(key);
              },
              flatMode: _flatMode,
              onFlatModeToggle: (v) => setState(() => _flatMode = v),
            )
          : const SizedBox.shrink(),
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
          activeStateFilters: _stateFilterStack.toSet(),
        ),
        Expanded(
          child: Builder(
            builder: (context) {
              final selectedSessions = context
                  .watch<SessionStore>()
                  .selectedSessionIds;
              final logListView = LogListView(
                tagFilter: _selectedSection,
                activeSeverities: _activeSeverities,
                textFilter: _effectiveFilter,
                selectedSessionIds: selectedSessions,
                selectionMode: _selectionMode,
                selectedEntryIds: _selectedEntryIds,
                onEntrySelected: _onEntrySelected,
                onEntryRangeSelected: _onEntryRangeSelected,
                bookmarkedEntryIds: _bookmarkedEntryIds,
                stickyOverrideIds: _stickyOverrideIds,
                flatMode: _flatMode,
                onFilterClear: () {
                  setState(() {
                    _activeSeverities = _defaultSeverities;
                    _textFilter = '';
                    _stateFilterStack = [];
                  });
                },
              );
              return Stack(
                children: [
                  _selectionMode
                      ? logListView
                      : SelectionArea(child: logListView),
                  if (_selectedEntryIds.isNotEmpty)
                    Positioned(
                      bottom: 12,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: SelectionActions(
                          selectedCount: _selectedEntryIds.length,
                          onCopy: _copySelected,
                          onExportJson: _exportSelectedJson,
                          onBookmark: _bookmarkSelected,
                          onSticky: _stickySelected,
                          onClear: _clearSelection,
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
