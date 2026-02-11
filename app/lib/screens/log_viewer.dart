import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/keybind.dart';
import '../models/server_broadcast.dart';
import '../models/viewer_message.dart';
import '../services/connection_manager.dart';
import '../services/filter_service.dart';
import '../services/keybind_registry.dart';
import '../services/log_store.dart';
import '../services/query_store.dart';
import '../services/rpc_service.dart';
import '../services/selection_service.dart';
import '../services/session_store.dart';
import '../services/settings_service.dart';
import '../services/uri_handler.dart';
import 'log_viewer_body.dart';

/// Main screen — the full log viewer UI.
class LogViewerScreen extends StatefulWidget {
  /// URL to auto-connect to. Pass null to skip auto-connect (e.g. in tests).
  final String? serverUrl;

  /// Optional `logger://` URI to handle on startup (filter/tab/clear).
  final String? launchUri;

  const LogViewerScreen({
    super.key,
    this.serverUrl = 'ws://localhost:8080/api/v2/stream',
    this.launchUri,
  });

  @override
  State<LogViewerScreen> createState() => _LogViewerScreenState();
}

class _LogViewerScreenState extends State<LogViewerScreen> {
  StreamSubscription<ServerBroadcast>? _messageSub;
  bool _hasEverReceivedEntries = false;
  String? _selectedSection;
  bool _settingsPanelVisible = false;
  bool _landingDelayActive = true;
  Timer? _landingDelayTimer;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _registerKeybinds();
      _setupQueryStore();
      _initConnection();
      _handleLaunchUri();
    });
    _landingDelayTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _landingDelayActive = false);
    });
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _messageSub?.cancel();
    _landingDelayTimer?.cancel();
    super.dispose();
  }

  void _registerKeybinds() {
    final registry = context.read<KeybindRegistry>();

    registry.register(
      const Keybind(
        id: 'toggle_mini',
        label: 'Toggle mini mode',
        category: 'View',
        key: LogicalKeyboardKey.keyM,
        ctrl: true,
      ),
      () {
        final settings = context.read<SettingsService>();
        settings.setMiniMode(!settings.miniMode);
        return true;
      },
    );

    registry.register(
      const Keybind(
        id: 'copy',
        label: 'Copy selection',
        category: 'Edit',
        key: LogicalKeyboardKey.keyC,
        ctrl: true,
      ),
      () {
        final ctx = primaryFocus?.context;
        if (ctx != null) {
          final action = Actions.maybeFind<CopySelectionTextIntent>(ctx);
          if (action != null) {
            Actions.invoke(ctx, CopySelectionTextIntent.copy);
            return true;
          }
        }
        return false;
      },
    );
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (context.read<KeybindRegistry>().handleKeyEvent(event)) return true;
    final selection = context.read<SelectionService>();
    final isShift = event.logicalKey == LogicalKeyboardKey.shiftLeft ||
        event.logicalKey == LogicalKeyboardKey.shiftRight;
    if (isShift && event is KeyDownEvent && !selection.selectionMode) {
      selection.setSelectionMode(true);
    } else if (isShift &&
        event is KeyUpEvent &&
        selection.selectionMode &&
        selection.selectedEntryIds.isEmpty) {
      selection.setSelectionMode(false);
    }
    return false;
  }

  void _initConnection() {
    final url = widget.serverUrl;
    if (url == null) return;

    final connection = context.read<ConnectionManager>();
    connection.addConnection(url, label: 'Default');
    _messageSub = connection.messages.listen(_handleMessage);
    connection.subscribe();

    context.read<SessionStore>().addListener(() {
      final selected = context.read<SessionStore>().selectedSessionIds;
      connection.subscribe(
        sessionIds: selected.isEmpty ? null : selected.toList(),
      );
    });

    connection.send(const ViewerSessionListMessage());
    connection.queryHistory(limit: 5000);
  }

  void _handleMessage(ServerBroadcast msg) {
    final logStore = context.read<LogStore>();
    final sessionStore = context.read<SessionStore>();

    switch (msg) {
      case EventBroadcast(:final entry):
        logStore.addEntry(entry);
        _markEntriesReceived();
      case HistoryMessage(:final entries):
        logStore.addEntries(entries);
        if (entries.isNotEmpty) _markEntriesReceived();
      case SessionListMessage(:final sessions):
        sessionStore.updateSessions(sessions);
      case SessionUpdateMessage():
        context.read<ConnectionManager>().send(
          const ViewerSessionListMessage(),
        );
      case RpcResponseMessage(:final rpcId, :final rpcResponse, :final rpcError):
        context.read<RpcService>().handleResponse(rpcId, rpcResponse, rpcError);
      case DataSnapshotMessage() || AckMessage() || ErrorMessage() ||
          RpcRequestMessage() || DataUpdateMessage() || SubscribeAckMessage():
        break;
    }
  }

  void _markEntriesReceived() {
    if (!_hasEverReceivedEntries) setState(() => _hasEverReceivedEntries = true);
  }

  void _setupQueryStore() {
    final queryStore = context.read<QueryStore>();
    queryStore.onQueryLoaded = (query) {
      context.read<FilterService>().loadQuery(
        severities: Set.from(query.severities),
        textFilter: query.textFilter,
      );
    };
  }

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

  @override
  Widget build(BuildContext context) {
    return LogViewerBody(
      selectedSection: _selectedSection,
      settingsPanelVisible: _settingsPanelVisible,
      hasEverReceivedEntries: _hasEverReceivedEntries,
      landingDelayActive: _landingDelayActive,
      onSectionChanged: (s) => setState(() => _selectedSection = s),
      onSettingsToggle: () =>
          setState(() => _settingsPanelVisible = !_settingsPanelVisible),
      onSettingsClose: () =>
          setState(() => _settingsPanelVisible = false),
      onSettingsOpen: () =>
          setState(() => _settingsPanelVisible = true),
    );
  }
}
