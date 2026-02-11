part of 'connection_manager.dart';

/// Internal wrapper for connection state + channel + timers.
class _ActiveConnection {
  final ServerConnection config;
  final WebSocketChannel? channel;
  final StreamSubscription<dynamic>? subscription;
  final Timer? reconnectTimer;

  _ActiveConnection({
    required this.config,
    this.channel,
    this.subscription,
    this.reconnectTimer,
  });

  _ActiveConnection withConfig(ServerConnection newConfig) => _ActiveConnection(
    config: newConfig,
    channel: channel,
    subscription: subscription,
    reconnectTimer: reconnectTimer,
  );
}

/// Connection lifecycle management (connect, disconnect, reconnect).
mixin _ConnectionLifecycle on ChangeNotifier {
  Map<String, _ActiveConnection> get _connections;
  StreamController<ServerBroadcast> get _messageController;

  Future<void> _connect(String id) async {
    final conn = _connections[id];
    if (conn == null) return;

    _connections[id] = conn.withConfig(
      conn.config.copyWith(state: ServerConnectionState.connecting),
    );
    notifyListeners();

    try {
      final channel = WebSocketChannel.connect(Uri.parse(conn.config.url));
      final sub = channel.stream.listen(
        (data) => _onData(id, data),
        onError: (error) => _onError(id, error),
        onDone: () => _onDone(id),
        cancelOnError: true,
      );

      // Wait for the WebSocket handshake to complete before marking connected
      try {
        await channel.ready;
      } catch (_) {
        // Handshake failed — trigger reconnect via onError/onDone path
        return;
      }

      // Only set connected if we're still in connecting state (not disposed)
      final current = _connections[id];
      if (current == null) return;

      _connections[id] = _ActiveConnection(
        config: current.config.copyWith(
          state: ServerConnectionState.connected,
          retryCount: 0,
          lastError: null,
        ),
        channel: channel,
        subscription: sub,
      );
      notifyListeners();
    } catch (e) {
      _connections[id] = conn.withConfig(
        conn.config.copyWith(
          state: ServerConnectionState.failed,
          lastError: '$e',
        ),
      );
      notifyListeners();
    }
  }

  void _disconnect(String id) {
    final conn = _connections[id];
    if (conn == null) return;
    conn.reconnectTimer?.cancel();
    conn.subscription?.cancel();
    conn.channel?.sink.close();
    _connections[id] = _ActiveConnection(
      config: conn.config.copyWith(
        state: ServerConnectionState.disconnected,
        retryCount: 0,
      ),
    );
  }

  void _onData(String id, dynamic data) {
    try {
      final json = jsonDecode(data as String) as Map<String, dynamic>;
      _messageController.add(ServerBroadcast.fromJson(json));
    } catch (e) {
      debugPrint('ConnectionManager[$id]: parse error: $e');
    }
  }

  void _onError(String id, Object error) {
    final conn = _connections[id];
    // Only log first error, suppress during reconnect
    if (conn != null && conn.config.retryCount == 0) {
      debugPrint('ConnectionManager[$id]: connection error: $error');
    }
    _scheduleReconnect(id);
  }

  void _onDone(String id) {
    _scheduleReconnect(id);
  }

  void _scheduleReconnect(String id) {
    final conn = _connections[id];
    if (conn == null || !conn.config.autoReconnect || !conn.config.enabled) {
      if (conn != null) {
        _connections[id] = conn.withConfig(
          conn.config.copyWith(state: ServerConnectionState.disconnected),
        );
        notifyListeners();
      }
      return;
    }

    final retryCount = conn.config.retryCount + 1;
    if (retryCount > 100) {
      _connections[id] = conn.withConfig(
        conn.config.copyWith(
          state: ServerConnectionState.failed,
          lastError: 'Max retries exceeded',
        ),
      );
      notifyListeners();
      return;
    }

    // Exponential backoff: 1s * 2^n, max 30s, ±25% jitter
    final baseDelay = min(1000 * pow(2, retryCount - 1), 30000).toInt();
    final jitter = (baseDelay * 0.25 * (Random().nextDouble() * 2 - 1)).toInt();
    final delay = Duration(milliseconds: baseDelay + jitter);

    final oldState = conn.config.state;
    _connections[id] = _ActiveConnection(
      config: conn.config.copyWith(
        state: ServerConnectionState.reconnecting,
        retryCount: retryCount,
      ),
      reconnectTimer: Timer(delay, () => _connect(id)),
    );
    if (oldState != ServerConnectionState.reconnecting) {
      notifyListeners();
    }
  }
}
