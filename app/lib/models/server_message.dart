/// Dart equivalents of the shared TypeScript ServerMessage schema.
library;

import 'log_entry.dart';

// ─── Server Message Types ────────────────────────────────────────────

enum ServerMessageType {
  ack,
  error,
  log,
  logs,
  rpcRequest,
  rpcResponse,
  sessionList,
  sessionUpdate,
  stateSnapshot,
  history,
  subscribeAck,
}

ServerMessageType parseServerMessageType(String value) {
  return switch (value) {
    'ack' => ServerMessageType.ack,
    'error' => ServerMessageType.error,
    'log' => ServerMessageType.log,
    'logs' => ServerMessageType.logs,
    'rpc_request' => ServerMessageType.rpcRequest,
    'rpc_response' => ServerMessageType.rpcResponse,
    'session_list' => ServerMessageType.sessionList,
    'session_update' => ServerMessageType.sessionUpdate,
    'state_snapshot' => ServerMessageType.stateSnapshot,
    'history' => ServerMessageType.history,
    'subscribe_ack' => ServerMessageType.subscribeAck,
    _ => ServerMessageType.error,
  };
}

// ─── Session Info ────────────────────────────────────────────────────

class SessionInfo {
  final String sessionId;
  final ApplicationInfo application;
  final String startedAt;
  final String lastHeartbeat;
  final bool isActive;
  final int logCount;
  final int colorIndex;

  const SessionInfo({
    required this.sessionId,
    required this.application,
    required this.startedAt,
    required this.lastHeartbeat,
    required this.isActive,
    required this.logCount,
    required this.colorIndex,
  });

  factory SessionInfo.fromJson(Map<String, dynamic> json) {
    return SessionInfo(
      sessionId: json['session_id'] as String,
      application: ApplicationInfo.fromJson(
        json['application'] as Map<String, dynamic>,
      ),
      startedAt: json['started_at'] as String,
      lastHeartbeat: json['last_heartbeat'] as String,
      isActive: json['is_active'] as bool,
      logCount: json['log_count'] as int,
      colorIndex: json['color_index'] as int,
    );
  }
}

// ─── Server Message ──────────────────────────────────────────────────

class ServerMessage {
  final ServerMessageType type;

  // ack
  final List<String>? ackIds;

  // error
  final String? errorCode;
  final String? errorMessage;
  final String? errorEntryId;

  // log
  final LogEntry? entry;

  // logs
  final List<LogEntry>? entries;

  // rpc
  final String? rpcId;
  final String? rpcMethod;
  final dynamic rpcArgs;
  final dynamic rpcResponse;
  final String? rpcError;

  // session_list
  final List<SessionInfo>? sessions;

  // session_update
  final String? sessionId;
  final SessionAction? sessionAction;
  final ApplicationInfo? application;

  // state_snapshot
  final Map<String, dynamic>? state;

  // history
  final String? queryId;
  final List<LogEntry>? historyEntries;
  final bool? hasMore;
  final String? cursor;

  const ServerMessage({
    required this.type,
    this.ackIds,
    this.errorCode,
    this.errorMessage,
    this.errorEntryId,
    this.entry,
    this.entries,
    this.rpcId,
    this.rpcMethod,
    this.rpcArgs,
    this.rpcResponse,
    this.rpcError,
    this.sessions,
    this.sessionId,
    this.sessionAction,
    this.application,
    this.state,
    this.queryId,
    this.historyEntries,
    this.hasMore,
    this.cursor,
  });

  factory ServerMessage.fromJson(Map<String, dynamic> json) {
    return ServerMessage(
      type: parseServerMessageType(json['type'] as String),
      ackIds: (json['ack_ids'] as List<dynamic>?)?.cast<String>(),
      errorCode: json['error_code'] as String?,
      errorMessage: json['error_message'] as String?,
      errorEntryId: json['error_entry_id'] as String?,
      entry: json['entry'] != null
          ? LogEntry.fromJson(json['entry'] as Map<String, dynamic>)
          : null,
      entries: (json['entries'] as List<dynamic>?)
          ?.map((e) => LogEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      rpcId: json['rpc_id'] as String?,
      rpcMethod: json['rpc_method'] as String?,
      rpcArgs: json['rpc_args'],
      rpcResponse: json['rpc_response'],
      rpcError: json['rpc_error'] as String?,
      sessions: (json['sessions'] as List<dynamic>?)
          ?.map((e) => SessionInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
      sessionId: json['session_id'] as String?,
      sessionAction: parseSessionAction(json['session_action'] as String?),
      application: json['application'] != null
          ? ApplicationInfo.fromJson(
              json['application'] as Map<String, dynamic>,
            )
          : null,
      state: (json['state'] as Map<String, dynamic>?),
      queryId: json['query_id'] as String?,
      historyEntries: (json['history_entries'] as List<dynamic>?)
          ?.map((e) => LogEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      hasMore: json['has_more'] as bool?,
      cursor: json['cursor'] as String?,
    );
  }
}
