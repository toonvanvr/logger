import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/server_message.dart';
import '../models/viewer_message.dart';

/// Manages the WebSocket connection to the log server.
class LogConnection extends ChangeNotifier {
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  final StreamController<ServerMessage> _messageController =
      StreamController<ServerMessage>.broadcast();

  bool get isConnected => _channel != null;

  /// Stream of incoming [ServerMessage]s from the server.
  Stream<ServerMessage> get messages => _messageController.stream;

  /// Connect to the log server at [url].
  void connect(String url) {
    disconnect();
    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      _subscription = _channel!.stream.listen(
        _onData,
        onError: _onError,
        onDone: _onDone,
      );
      notifyListeners();
    } catch (e) {
      _channel = null;
      notifyListeners();
    }
  }

  /// Disconnect from the server.
  void disconnect() {
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
    notifyListeners();
  }

  /// Send a [ViewerMessage] to the server.
  void send(ViewerMessage message) {
    _channel?.sink.add(message.toJsonString());
  }

  /// Subscribe to sessions with optional filters.
  void subscribe({List<String>? sessionIds, String? minSeverity}) {
    send(
      ViewerMessage(
        type: ViewerMessageType.subscribe,
        sessionIds: sessionIds,
        minSeverity: minSeverity,
      ),
    );
  }

  /// Request log history.
  void queryHistory({
    String? queryId,
    String? from,
    String? to,
    String? sessionId,
    int? limit,
    String? cursor,
    String? source,
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
        source: source,
      ),
    );
  }

  void _onData(dynamic data) {
    try {
      final json = jsonDecode(data as String) as Map<String, dynamic>;
      final message = ServerMessage.fromJson(json);
      _messageController.add(message);
    } catch (e) {
      debugPrint('LogConnection: failed to parse message: $e');
    }
  }

  void _onError(Object error) {
    debugPrint('LogConnection: WebSocket error: $error');
    _channel = null;
    _subscription = null;
    notifyListeners();
  }

  void _onDone() {
    _channel = null;
    _subscription = null;
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    _messageController.close();
    super.dispose();
  }
}
