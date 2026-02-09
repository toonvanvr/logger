part of 'log_viewer.dart';

/// Connection lifecycle and server message handling for the log viewer.
///
/// Manages WebSocket subscription, message routing, and session tracking.
mixin _ConnectionMixin on State<LogViewerScreen> {
  StreamSubscription<ServerMessage>? _messageSub;

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

    switch (msg.type) {
      case ServerMessageType.event:
        if (msg.entry != null) logStore.addEntry(msg.entry!);
      case ServerMessageType.eventBatch:
        if (msg.entries != null) logStore.addEntries(msg.entries!);
      case ServerMessageType.history:
        if (msg.historyEntries != null) {
          logStore.addEntries(msg.historyEntries!);
        }
      case ServerMessageType.sessionList:
        if (msg.sessions != null) sessionStore.updateSessions(msg.sessions!);
      case ServerMessageType.sessionUpdate:
        // Re-fetch full session list to pick up new/ended sessions
        context.read<ConnectionManager>().send(
          const ViewerMessage(type: ViewerMessageType.sessionList),
        );
        break;
      case ServerMessageType.dataSnapshot:
        // Data snapshots are handled via LogStore state tracking
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
}
