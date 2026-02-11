import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/server_broadcast.dart';
import '../models/server_connection.dart';
import '../models/viewer_message.dart';

part 'connection_reconnect.dart';

/// Manages multiple server connections with auto-reconnect.
class ConnectionManager extends ChangeNotifier with _ConnectionLifecycle {
  @override
  final Map<String, _ActiveConnection> _connections = {};
  @override
  final StreamController<ServerBroadcast> _messageController =
      StreamController<ServerBroadcast>.broadcast();

  // ─── Public API ─────────────────────────────────────────────────

  Map<String, ServerConnection> get connections =>
      _connections.map((id, c) => MapEntry(id, c.config));

  int get activeCount =>
      _connections.values.where((c) => c.config.isActive).length;

  Stream<ServerBroadcast> get messages => _messageController.stream;

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
      ViewerSubscribeMessage(sessionIds: sessionIds, minSeverity: minSeverity),
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
      ViewerHistoryQueryMessage(
        queryId: queryId,
        from: from,
        to: to,
        sessionId: sessionId,
        limit: limit,
        cursor: cursor,
      ),
    );
  }

  bool get isConnected => activeCount > 0;

  @override
  void dispose() {
    for (final id in _connections.keys.toList()) {
      _disconnect(id);
    }
    _messageController.close();
    super.dispose();
  }
}
