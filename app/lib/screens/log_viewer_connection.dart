part of 'log_viewer.dart';

/// Connection lifecycle and server message handling for the log viewer.
///
/// Manages WebSocket subscription, message routing, and session tracking.
mixin _ConnectionMixin on State<LogViewerScreen> {
  StreamSubscription<ServerMessage>? _messageSub;
  bool _hasEverReceivedEntries = false;

  void _initConnection() {
    final url = widget.serverUrl;
    if (url == null) return;

    final connection = context.read<ConnectionManager>();
    connection.addConnection(url, label: 'Default');

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

    switch (msg) {
      case EventMessage(:final entry):
        logStore.addEntry(entry);
        _markEntriesReceived();
      case EventBatchMessage(:final entries):
        logStore.addEntries(entries);
        if (entries.isNotEmpty) _markEntriesReceived();
      case HistoryMessage(:final entries):
        logStore.addEntries(entries);
        if (entries.isNotEmpty) _markEntriesReceived();
      case SessionListMessage(:final sessions):
        sessionStore.updateSessions(sessions);
      case SessionUpdateMessage():
        // Re-fetch full session list to pick up new/ended sessions
        context.read<ConnectionManager>().send(
          const ViewerMessage(type: ViewerMessageType.sessionList),
        );
      case DataSnapshotMessage():
        // Data snapshots are handled via LogStore state tracking
        break;
      case RpcResponseMessage(
        :final rpcId,
        :final rpcResponse,
        :final rpcError,
      ):
        context.read<RpcService>().handleResponse(rpcId, rpcResponse, rpcError);
      case AckMessage() ||
          ErrorMessage() ||
          RpcRequestMessage() ||
          DataUpdateMessage() ||
          SubscribeAckMessage():
        break;
    }
  }

  /// Mark that entries have been received, preventing landing page from showing.
  void _markEntriesReceived() {
    if (!_hasEverReceivedEntries) {
      setState(() => _hasEverReceivedEntries = true);
    }
  }
}
