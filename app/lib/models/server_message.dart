/// Dart equivalents of the v2 ServerMessage schema.
library;

import 'log_entry.dart';

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

// ─── Server Message (sealed hierarchy) ───────────────────────────────

sealed class ServerMessage {
  const ServerMessage();

  factory ServerMessage.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String? ?? 'error';
    return switch (typeStr) {
      'ack' => AckMessage(
        ackIds: (json['ack_ids'] as List<dynamic>?)?.cast<String>() ?? [],
      ),
      'error' => ErrorMessage(
        errorCode: json['error_code'] as String?,
        errorMessage: json['error_message'] as String?,
        errorEntryId: json['error_entry_id'] as String?,
      ),
      'event' || 'log' =>
        json['entry'] != null
            ? EventMessage(
                entry: LogEntry.fromJson(json['entry'] as Map<String, dynamic>),
              )
            : ErrorMessage(errorMessage: 'event missing entry'),
      'event_batch' => EventBatchMessage(
        entries:
            (json['entries'] as List<dynamic>?)
                ?.map((e) => LogEntry.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      ),
      'rpc_request' =>
        json['rpc_id'] != null && json['rpc_method'] != null
            ? RpcRequestMessage(
                rpcId: json['rpc_id'] as String,
                rpcMethod: json['rpc_method'] as String,
                rpcArgs: json['rpc_args'],
              )
            : ErrorMessage(
                errorMessage: 'rpc_request missing rpc_id or rpc_method',
              ),
      'rpc_response' =>
        json['rpc_id'] != null
            ? RpcResponseMessage(
                rpcId: json['rpc_id'] as String,
                rpcResponse: json['rpc_response'],
                rpcError: json['rpc_error'] as String?,
              )
            : ErrorMessage(errorMessage: 'rpc_response missing rpc_id'),
      'session_list' => SessionListMessage(
        sessions:
            (json['sessions'] as List<dynamic>?)
                ?.map((e) => SessionInfo.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      ),
      'session_update' => SessionUpdateMessage(
        sessionId: json['session_id'] as String?,
        sessionAction: parseSessionAction(json['action'] as String?),          
        application: json['application'] != null
            ? ApplicationInfo.fromJson(
                json['application'] as Map<String, dynamic>,
              )
            : null,
      ),
      'data_snapshot' => DataSnapshotMessage(
        data:
            (json['data'] as Map<String, dynamic>?)?.map(
              (k, v) =>
                  MapEntry(k, DataState.fromJson(v as Map<String, dynamic>)),
            ) ??
            {},
      ),
      'data_update' =>
        json['data_key'] != null
            ? DataUpdateMessage(
                dataKey: json['data_key'] as String,
                dataValue: json['data_value'],
                dataDisplay: json['data_display'] != null
                    ? parseDisplayLocation(json['data_display'] as String)
                    : null,
                dataWidget: json['data_widget'] != null
                    ? WidgetPayload.fromJson(
                        json['data_widget'] as Map<String, dynamic>,
                      )
                    : null,
              )
            : ErrorMessage(errorMessage: 'data_update missing data_key'),
      'history' => HistoryMessage(
        queryId: json['query_id'] as String?,
        entries:
            (json['history_entries'] as List<dynamic>?)
                ?.map((e) => LogEntry.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        hasMore: json['has_more'] as bool? ?? false,
        cursor: json['cursor'] as String?,
        source: json['source'] as String?,
        fenceTs: json['fence_ts'] as String?,
      ),
      'subscribe_ack' => const SubscribeAckMessage(),
      _ => ErrorMessage(errorMessage: 'unknown type: $typeStr'),
    };
  }
}

class AckMessage extends ServerMessage {
  final List<String> ackIds;
  const AckMessage({this.ackIds = const []});
}

class ErrorMessage extends ServerMessage {
  final String? errorCode;
  final String? errorMessage;
  final String? errorEntryId;
  const ErrorMessage({this.errorCode, this.errorMessage, this.errorEntryId});
}

class EventMessage extends ServerMessage {
  final LogEntry entry;
  const EventMessage({required this.entry});
}

class EventBatchMessage extends ServerMessage {
  final List<LogEntry> entries;
  const EventBatchMessage({this.entries = const []});
}

class RpcRequestMessage extends ServerMessage {
  final String rpcId;
  final String rpcMethod;
  final dynamic rpcArgs;
  const RpcRequestMessage({
    required this.rpcId,
    required this.rpcMethod,
    this.rpcArgs,
  });
}

class RpcResponseMessage extends ServerMessage {
  final String rpcId;
  final dynamic rpcResponse;
  final String? rpcError;
  const RpcResponseMessage({
    required this.rpcId,
    this.rpcResponse,
    this.rpcError,
  });
}

class SessionListMessage extends ServerMessage {
  final List<SessionInfo> sessions;
  const SessionListMessage({this.sessions = const []});
}

class SessionUpdateMessage extends ServerMessage {
  final String? sessionId;
  final SessionAction? sessionAction;
  final ApplicationInfo? application;
  const SessionUpdateMessage({
    this.sessionId,
    this.sessionAction,
    this.application,
  });
}

class DataSnapshotMessage extends ServerMessage {
  final Map<String, DataState> data;
  const DataSnapshotMessage({this.data = const {}});
}

class DataUpdateMessage extends ServerMessage {
  final String dataKey;
  final dynamic dataValue;
  final DisplayLocation? dataDisplay;
  final WidgetPayload? dataWidget;
  const DataUpdateMessage({
    required this.dataKey,
    this.dataValue,
    this.dataDisplay,
    this.dataWidget,
  });
}

class HistoryMessage extends ServerMessage {
  final String? queryId;
  final List<LogEntry> entries;
  final bool hasMore;
  final String? cursor;

  /// Which backend served this response: 'buffer' or 'store'.
  final String? source;

  /// ISO 8601 server timestamp when query was executed (for dedup).
  final String? fenceTs;

  const HistoryMessage({
    this.queryId,
    this.entries = const [],
    this.hasMore = false,
    this.cursor,
    this.source,
    this.fenceTs,
  });
}

class SubscribeAckMessage extends ServerMessage {
  const SubscribeAckMessage();
}
