import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/viewer_message.dart';
import 'connection_manager.dart';

// ─── Data classes ────────────────────────────────────────────────────

/// Describes an RPC tool exposed by a client session.
class RpcToolInfo {
  final String name;
  final String description;
  final String category; // 'getter' or 'tool'
  final Map<String, dynamic>? argsSchema;
  final bool confirm;

  const RpcToolInfo({
    required this.name,
    required this.description,
    required this.category,
    this.argsSchema,
    this.confirm = false,
  });
}

/// The result of an RPC invocation.
class RpcResult {
  final dynamic data;
  final String? error;
  final DateTime timestamp;

  const RpcResult({this.data, this.error, required this.timestamp});
}

// ─── Service ─────────────────────────────────────────────────────────

/// Manages RPC tool registration and invocation.
class RpcService extends ChangeNotifier {
  static const _uuid = Uuid();

  final Map<String, List<RpcToolInfo>> _tools = {};
  final Map<String, RpcResult> _results = {};
  final Map<String, Completer<dynamic>> _pending = {};

  /// Tools grouped by session ID.
  Map<String, List<RpcToolInfo>> get tools => Map.unmodifiable(_tools);

  /// Stored results keyed by rpcId.
  Map<String, RpcResult> get results => Map.unmodifiable(_results);

  /// Update the available tools for a session.
  void updateTools(String sessionId, List<RpcToolInfo> tools) {
    _tools[sessionId] = tools;
    notifyListeners();
  }

  /// Invoke an RPC method on a session via the log connection.
  ///
  /// Returns a [Future] that completes when the server sends back
  /// an `rpc_response` with the matching `rpc_id`.
  Future<dynamic> invoke(
    String sessionId,
    String method,
    dynamic args,
    ConnectionManager connection,
  ) {
    final rpcId = _uuid.v4();
    final completer = Completer<dynamic>();
    _pending[rpcId] = completer;

    connection.send(
      ViewerRpcRequestMessage(
        rpcId: rpcId,
        targetSessionId: sessionId,
        method: method,
        args: args,
      ),
    );

    return completer.future;
  }

  /// Handle an incoming RPC response from the server.
  void handleResponse(String rpcId, dynamic data, String? error) {
    final result = RpcResult(
      data: data,
      error: error,
      timestamp: DateTime.now(),
    );
    _results[rpcId] = result;

    final completer = _pending.remove(rpcId);
    if (completer != null && !completer.isCompleted) {
      if (error != null) {
        completer.completeError(error);
      } else {
        completer.complete(data);
      }
    }

    notifyListeners();
  }
}
