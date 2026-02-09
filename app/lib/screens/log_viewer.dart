import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/server_message.dart';
import '../models/viewer_message.dart';
import '../services/connection_manager.dart';
import '../services/log_store.dart';
import '../services/query_store.dart';
import '../services/rpc_service.dart';
import '../services/session_store.dart';
import '../services/settings_service.dart';
import '../services/uri_handler.dart';
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

part 'log_viewer_connection.dart';
part 'log_viewer_selection.dart';

/// Main screen — the full log viewer UI.
class LogViewerScreen extends StatefulWidget {
  /// URL to auto-connect to. Pass null to skip auto-connect (e.g. in tests).
  final String? serverUrl;

  /// Optional `logger://` URI to handle on startup (filter/tab/clear).
  final String? launchUri;

  const LogViewerScreen({
    super.key,
    this.serverUrl = 'ws://localhost:8080/api/v1/stream',
    this.launchUri,
  });

  @override
  State<LogViewerScreen> createState() => _LogViewerScreenState();
}

class _LogViewerScreenState extends State<LogViewerScreen>
    with _SelectionMixin, _ConnectionMixin {
  static const Set<String> _defaultSeverities = {
    'debug',
    'info',
    'warning',
    'error',
    'critical',
  };

  bool _isFilterExpanded = false;
  Set<String> _activeSeverities = _defaultSeverities;
  String _textFilter = '';
  List<String> _stateFilterStack = [];
  String? _selectedSection;
  bool _settingsPanelVisible = false;
  bool _hasEverReceivedEntries = false;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupQueryStore();
      _initConnection();
      _handleLaunchUri();
    });
  }

  void _setupQueryStore() {
    final queryStore = context.read<QueryStore>();
    queryStore.onQueryLoaded = (query) {
      setState(() {
        _activeSeverities = Set.from(query.severities);
        _textFilter = query.textFilter;
        _stateFilterStack = [];
      });
    };
  }

  /// Process launch URI for filter, tab, and clear actions.
  void _handleLaunchUri() {
    final uri = widget.launchUri;
    if (uri == null) return;
    UriHandler.handleUri(
      uri,
      connectionManager: context.read<ConnectionManager>(),
      onFilter: (query) => setState(() => _textFilter = query),
      onTab: (name) => setState(() => _selectedSection = name),
      onClear: () => setState(() {
        _activeSeverities = _defaultSeverities;
        _textFilter = '';
        _stateFilterStack = [];
      }),
    );
  }

  /// Composes the effective filter from user text and state filter stack.
  String get _effectiveFilter {
    final parts = [
      _textFilter,
      ..._stateFilterStack.map((k) => 'state:$k'),
    ].where((s) => s.isNotEmpty);
    return parts.join(' ');
  }

  /// Toggles a state key in/out of the filter stack.
  void _toggleStateFilter(String stateKey) {
    setState(() {
      if (_stateFilterStack.contains(stateKey)) {
        _stateFilterStack.remove(stateKey);
      } else {
        _stateFilterStack.add(stateKey);
      }
      _isFilterExpanded = true;
    });
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _messageSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              if (settings.miniMode)
                MiniTitleBar(
                  isFilterExpanded: _isFilterExpanded,
                  onFilterToggle: () {
                    setState(() => _isFilterExpanded = !_isFilterExpanded);
                  },
                  onSettingsToggle: () {
                    setState(
                      () => _settingsPanelVisible = !_settingsPanelVisible,
                    );
                  },
                )
              else
                SessionSelector(
                  isFilterExpanded: _isFilterExpanded,
                  onFilterToggle: () {
                    setState(() => _isFilterExpanded = !_isFilterExpanded);
                  },
                  onRpcToggle: () {
                    setState(
                      () => _settingsPanelVisible = !_settingsPanelVisible,
                    );
                  },
                ),
              AnimatedSize(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeInOut,
                alignment: Alignment.topCenter,
                child: _isFilterExpanded
                    ? FilterBar(
                        activeSeverities: _activeSeverities,
                        onSeverityChange: (severities) {
                          setState(() => _activeSeverities = severities);
                        },
                        onTextFilterChange: (text) {
                          setState(() => _textFilter = text);
                        },
                        onClear: () {
                          setState(() {
                            _activeSeverities = _defaultSeverities;
                            _textFilter = '';
                            _stateFilterStack = [];
                          });
                        },
                      )
                    : const SizedBox.shrink(),
              ),
              Expanded(
                child: Builder(
                  builder: (context) {
                    final logStore = context.watch<LogStore>();
                    final connMgr = context.watch<ConnectionManager>();
                    if (logStore.entries.isNotEmpty) {
                      _hasEverReceivedEntries = true;
                    }
                    final showLanding =
                        !_hasEverReceivedEntries && connMgr.activeCount == 0;
                    return AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
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
              ),
              const StatusBar(),
            ],
          ),
          // Scrim backdrop when settings panel is open
          Positioned(
            left: 0,
            right: 0,
            top: settings.miniMode ? 28 : 40,
            bottom: 0,
            child: IgnorePointer(
              ignoring: !_settingsPanelVisible,
              child: AnimatedOpacity(
                opacity: _settingsPanelVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: GestureDetector(
                  onTap: () {
                    setState(() => _settingsPanelVisible = false);
                  },
                  child: const ColoredBox(color: Color(0x40000000)),
                ),
              ),
            ),
          ),
          // Settings panel overlay
          Positioned(
            right: 0,
            top: settings.miniMode ? 28 : 40,
            bottom: 0,
            child: SettingsPanel(
              isVisible: _settingsPanelVisible,
              onClose: () {
                setState(() => _settingsPanelVisible = false);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(BuildContext context) {
    return Column(
      key: const ValueKey('content'),
      children: [
        Builder(
          builder: (context) {
            final logStore = context.watch<LogStore>();
            final sections =
                logStore.entries
                    .map((e) => e.section)
                    .whereType<String>()
                    .toSet()
                    .toList()
                  ..sort();
            return SectionTabs(
              sections: sections,
              selectedSection: _selectedSection,
              onSectionChanged: (section) {
                setState(() => _selectedSection = section);
              },
            );
          },
        ),
        StateViewSection(
          onStateFilter: (filter) {
            // Extract raw key from 'state:key' format
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
              return Stack(
                children: [
                  SelectionArea(
                    child: LogListView(
                      sectionFilter: _selectedSection,
                      activeSeverities: _activeSeverities,
                      textFilter: _effectiveFilter,
                      selectedSessionIds: selectedSessions,
                      selectionMode: _selectionMode,
                      selectedEntryIds: _selectedEntryIds,
                      onEntrySelected: _onEntrySelected,
                      onEntryRangeSelected: _onEntryRangeSelected,
                      bookmarkedEntryIds: _bookmarkedEntryIds,
                      stickyOverrideIds: _stickyOverrideIds,
                      onFilterClear: () {
                        setState(() {
                          _activeSeverities = _defaultSeverities;
                          _textFilter = '';
                          _stateFilterStack = [];
                        });
                      },
                    ),
                  ),
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
