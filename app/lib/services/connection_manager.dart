import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/server_connection.dart';
import '../models/server_message.dart';
import '../models/viewer_message.dart';

/// Manages multiple server connections with auto-reconnect.
class ConnectionManager extends ChangeNotifier {
  final Map<String, _ActiveConnection> _connections = {};
  final StreamController<ServerMessage> _messageController =
      StreamController<ServerMessage>.broadcast();

  // ─── Public API ─────────────────────────────────────────────────

  Map<String, ServerConnection> get connections =>
      _connections.map((id, c) => MapEntry(id, c.config));

  int get activeCount =>
      _connections.values.where((c) => c.config.isActive).length;

  Stream<ServerMessage> get messages => _messageController.stream;

  /// Add a new server connection and optionally connect immediately.
  String addConnection(String url, {String? label, bool connect = true}) {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final config = ServerConnection(id: id, url: url, label: label);
    _connections[id] = _ActiveConnection(config: config);
    if (connect) _connect(id);
    notifyListeners();
    return id;
  }

  void removeConnection(String id) {
    _disconnect(id);
    _connections.remove(id);
    notifyListeners();
  }

  void updateConnection(String id, ServerConnection config) {
    final existing = _connections[id];
    if (existing == null) return;
    _disconnect(id);
    _connections[id] = _ActiveConnection(config: config);
    if (config.enabled) _connect(id);
    notifyListeners();
  }

  void toggleConnection(String id) {
    final conn = _connections[id];
    if (conn == null) return;
    final toggled = conn.config.copyWith(enabled: !conn.config.enabled);
    updateConnection(id, toggled);
  }

  /// Send a message to a specific connection, or broadcast to all active.
  void send(ViewerMessage message, {String? connectionId}) {
    if (connectionId != null) {
      _connections[connectionId]?.channel?.sink.add(message.toJsonString());
    } else {
      for (final conn in _connections.values) {
        conn.channel?.sink.add(message.toJsonString());
      }
    }
  }

  void subscribe({List<String>? sessionIds, String? minSeverity}) {
    send(
      ViewerMessage(
        type: ViewerMessageType.subscribe,
        sessionIds: sessionIds,
        minSeverity: minSeverity,
      ),
    );
  }

  void queryHistory({
    String? queryId,
    String? from,
    String? to,
    String? sessionId,
    int? limit,
    String? cursor,
  }) {
    send(
      ViewerMessage(
        type: ViewerMessageType.historyQuery,
        queryId: queryId,
        from: from,
        to: to,
        sessionId: sessionId,
        limit: limit,
        cursor: cursor,
      ),
    );
  }

  /// For backward compatibility.
  bool get isConnected => activeCount > 0;

  // ─── Private ────────────────────────────────────────────────────

  void _connect(String id) {
    final conn = _connections[id];
    if (conn == null) return;

    _connections[id] = conn.withConfig(
      conn.config.copyWith(state: ServerConnectionState.connecting),
    );
    notifyListeners();

    try {
      final channel = WebSocketChannel.connect(Uri.parse(conn.config.url));
      channel.ready.catchError((_) {}); // Errors handled via stream onError
      final sub = channel.stream.listen(
        (data) => _onData(id, data),
        onError: (error) => _onError(id, error),
        onDone: () => _onDone(id),
        cancelOnError: true,
      );
      _connections[id] = _ActiveConnection(
        config: conn.config.copyWith(
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
      _messageController.add(ServerMessage.fromJson(json));
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

  @override
  void dispose() {
    for (final id in _connections.keys.toList()) {
      _disconnect(id);
    }
    _messageController.close();
    super.dispose();
  }
}

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
