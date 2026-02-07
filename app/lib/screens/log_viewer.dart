import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/server_message.dart';
import '../services/log_connection.dart';
import '../services/log_store.dart';
import '../services/rpc_service.dart';
import '../services/session_store.dart';
import '../widgets/header/filter_bar.dart';
import '../widgets/header/session_selector.dart';
import '../widgets/log_list/log_list_view.dart';
import '../widgets/log_list/section_tabs.dart';
import '../widgets/rpc/rpc_panel.dart';
import '../widgets/time_travel/time_travel_controls.dart';

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
  // TODO(log-list): Wire text filter into LogListView.
  // ignore: unused_field
  String _textFilter = '';
  String? _selectedSection;
  bool _timeTravelActive = false;
  bool _rpcPanelVisible = false;

  @override
  void initState() {
    super.initState();
    // Defer connection to after the first frame to avoid notifyListeners during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initConnection();
    });
  }

  void _initConnection() {
    final url = widget.serverUrl;
    if (url == null) return;

    final connection = context.read<LogConnection>();
    connection.connect(url);

    _messageSub = connection.messages.listen(_handleMessage);
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
        // Handled via session_list refresh
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
                    setState(() => _rpcPanelVisible = !_rpcPanelVisible);
                  },
                ),
                if (_isFilterExpanded)
                  FilterBar(
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
                  child: LogListView(
                    sectionFilter: _selectedSection,
                    activeSeverities: _activeSeverities,
                  ),
                ),
                // Time travel controls at bottom
                TimeTravelControls(
                  isActive: _timeTravelActive,
                  onToggle: () {
                    setState(() => _timeTravelActive = !_timeTravelActive);
                  },
                  onGoToLive: () {
                    setState(() => _timeTravelActive = false);
                  },
                ),
              ],
            ),
          ),
          // RPC panel
          RpcPanel(
            isVisible: _rpcPanelVisible,
            onClose: () {
              setState(() => _rpcPanelVisible = false);
            },
          ),
        ],
      ),
    );
  }
}
