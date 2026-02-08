import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/server_message.dart';
import '../models/viewer_message.dart';
import '../services/log_connection.dart';
import '../services/log_store.dart';
import '../services/query_store.dart';
import '../services/rpc_service.dart';
import '../services/session_store.dart';
import '../widgets/header/filter_bar.dart';
import '../widgets/header/session_selector.dart';
import '../widgets/log_list/log_list_view.dart';
import '../widgets/log_list/section_tabs.dart';
import '../widgets/settings/settings_panel.dart';
import '../widgets/status_bar/status_bar.dart';
import '../widgets/time_travel/time_range_minimap.dart';

/// Main screen — placeholder for the full log viewer UI.
class LogViewerScreen extends StatefulWidget {
  /// URL to auto-connect to. Pass null to skip auto-connect (e.g. in tests).
  final String? serverUrl;

  const LogViewerScreen({
    super.key,
    this.serverUrl = 'ws://localhost:8080/api/v1/stream',
  });

  @override
  State<LogViewerScreen> createState() => _LogViewerScreenState();
}

class _LogViewerScreenState extends State<LogViewerScreen> {
  StreamSubscription<ServerMessage>? _messageSub;
  bool _isFilterExpanded = false;
  Set<String> _activeSeverities = const {
    'debug',
    'info',
    'warning',
    'error',
    'critical',
  };
  String _textFilter = '';
  String? _selectedSection;
  bool _settingsPanelVisible = false;

  @override
  void initState() {
    super.initState();
    // Defer connection to after the first frame to avoid notifyListeners during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initConnection();
    });
  }

  void _initConnection() {
    // Wire up saved-query loading
    final queryStore = context.read<QueryStore>();
    queryStore.onQueryLoaded = (query) {
      setState(() {
        _activeSeverities = Set.from(query.severities);
        _textFilter = query.textFilter;
      });
    };

    final url = widget.serverUrl;
    if (url == null) return;

    final connection = context.read<LogConnection>();
    connection.connect(url);

    _messageSub = connection.messages.listen(_handleMessage);

    // Register subscription with server so we receive broadcasts
    connection.subscribe();

    // Re-subscribe when session selection changes
    context.read<SessionStore>().addListener(() {
      final selected = context.read<SessionStore>().selectedSessionIds;
      connection.subscribe(
        sessionIds: selected.isEmpty ? null : selected.toList(),
      );
    });

    // Request current session list
    connection.send(const ViewerMessage(type: ViewerMessageType.sessionList));

    // Load existing entries from the server's ring buffer
    connection.queryHistory(limit: 5000);
  }

  void _handleMessage(ServerMessage msg) {
    final logStore = context.read<LogStore>();
    final sessionStore = context.read<SessionStore>();

    switch (msg.type) {
      case ServerMessageType.log:
        if (msg.entry != null) logStore.addEntry(msg.entry!);
      case ServerMessageType.logs:
        if (msg.entries != null) logStore.addEntries(msg.entries!);
      case ServerMessageType.history:
        if (msg.historyEntries != null) {
          logStore.addEntries(msg.historyEntries!);
        }
      case ServerMessageType.sessionList:
        if (msg.sessions != null) sessionStore.updateSessions(msg.sessions!);
      case ServerMessageType.sessionUpdate:
        // Re-fetch full session list to pick up new/ended sessions
        context.read<LogConnection>().send(
          const ViewerMessage(type: ViewerMessageType.sessionList),
        );
        break;
      case ServerMessageType.stateSnapshot:
        // State snapshots are handled via LogStore state tracking
        break;
      case ServerMessageType.rpcResponse:
        if (msg.rpcId != null) {
          context.read<RpcService>().handleResponse(
            msg.rpcId!,
            msg.rpcResponse,
            msg.rpcError,
          );
        }
      default:
        break;
    }
  }

  @override
  void dispose() {
    _messageSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Main content column
          Expanded(
            child: Column(
              children: [
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
                              _activeSeverities = const {
                                'debug',
                                'info',
                                'warning',
                                'error',
                                'critical',
                              };
                              _textFilter = '';
                            });
                          },
                        )
                      : const SizedBox.shrink(),
                ),
                // Section tabs
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
                // Log list
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final selectedSessions = context
                          .watch<SessionStore>()
                          .selectedSessionIds;
                      return LogListView(
                        sectionFilter: _selectedSection,
                        activeSeverities: _activeSeverities,
                        textFilter: _textFilter,
                        selectedSessionIds: selectedSessions,
                      );
                    },
                  ),
                ),
                // Time range minimap
                const TimeRangeMinimap(),
                const StatusBar(),
              ],
            ),
          ),
          // Settings panel
          SettingsPanel(
            isVisible: _settingsPanelVisible,
            onClose: () {
              setState(() => _settingsPanelVisible = false);
            },
          ),
        ],
      ),
    );
  }
}
