/// Dart equivalents of the v2 ServerBroadcast schema.
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

sealed class ServerBroadcast {
  const ServerBroadcast();

  factory ServerBroadcast.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String? ?? 'error';
    return switch (typeStr) {
      'ack' => AckMessage(
        ids: (json['ids'] as List<dynamic>?)?.cast<String>() ?? [],
      ),
      'error' => ErrorMessage(
        code: json['code'] as String?,
        message: json['message'] as String?,
        errorEntryId: json['entry_id'] as String?,
      ),
      'event' || 'log' =>
        json['entry'] != null
            ? EventBroadcast(
                entry: LogEntry.fromJson(json['entry'] as Map<String, dynamic>),
              )
            : ErrorMessage(message: 'event missing entry'),
      'rpc_request' =>
        json['rpc_id'] != null && json['method'] != null
            ? RpcRequestMessage(
                rpcId: json['rpc_id'] as String,
                method: json['method'] as String,
                args: json['args'],
              )
            : ErrorMessage(message: 'rpc_request missing rpc_id or method'),
      'rpc_response' =>
        json['rpc_id'] != null
            ? RpcResponseMessage(
                rpcId: json['rpc_id'] as String,
                rpcResponse: json['result'],
                rpcError: json['error'] as String?,
              )
            : ErrorMessage(message: 'rpc_response missing rpc_id'),
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
        sessionId: json['session_id'] as String?,
        data:
            (json['data'] as Map<String, dynamic>?)?.map(
              (k, v) =>
                  MapEntry(k, DataState.fromJson(v as Map<String, dynamic>)),
            ) ??
            {},
      ),
      'data_update' =>
        json['key'] != null
            ? DataUpdateMessage(
                sessionId: json['session_id'] as String?,
                key: json['key'] as String,
                value: json['value'],
                display: json['display'] != null
                    ? parseDisplayLocation(json['display'] as String)
                    : null,
                widget: json['widget'] != null
                    ? WidgetPayload.fromJson(
                        json['widget'] as Map<String, dynamic>,
                      )
                    : null,
              )
            : ErrorMessage(message: 'data_update missing key'),
      'history' => HistoryMessage(
        queryId: json['query_id'] as String?,
        entries:
            (json['entries'] as List<dynamic>?)
                ?.map((e) => LogEntry.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        hasMore: json['has_more'] as bool? ?? false,
        cursor: json['cursor'] as String?,
        source: json['source'] as String?,
        fenceTs: json['fence_ts'] as String?,
      ),
      'subscribe_ack' => const SubscribeAckMessage(),
      _ => ErrorMessage(message: 'unknown type: $typeStr'),
    };
  }
}

class AckMessage extends ServerBroadcast {
  final List<String> ids;
  const AckMessage({this.ids = const []});
}

class ErrorMessage extends ServerBroadcast {
  final String? code;
  final String? message;
  final String? errorEntryId;
  const ErrorMessage({this.code, this.message, this.errorEntryId});
}

class EventBroadcast extends ServerBroadcast {
  final LogEntry entry;
  const EventBroadcast({required this.entry});
}

class RpcRequestMessage extends ServerBroadcast {
  final String rpcId;
  final String method;
  final dynamic args;
  const RpcRequestMessage({
    required this.rpcId,
    required this.method,
    this.args,
  });
}

class RpcResponseMessage extends ServerBroadcast {
  final String rpcId;
  final dynamic rpcResponse;
  final String? rpcError;
  const RpcResponseMessage({
    required this.rpcId,
    this.rpcResponse,
    this.rpcError,
  });
}

class SessionListMessage extends ServerBroadcast {
  final List<SessionInfo> sessions;
  const SessionListMessage({this.sessions = const []});
}

class SessionUpdateMessage extends ServerBroadcast {
  final String? sessionId;
  final SessionAction? sessionAction;
  final ApplicationInfo? application;
  const SessionUpdateMessage({
    this.sessionId,
    this.sessionAction,
    this.application,
  });
}

class DataSnapshotMessage extends ServerBroadcast {
  final String? sessionId;
  final Map<String, DataState> data;
  const DataSnapshotMessage({this.sessionId, this.data = const {}});
}

class DataUpdateMessage extends ServerBroadcast {
  final String? sessionId;
  final String key;
  final dynamic value;
  final DisplayLocation? display;
  final WidgetPayload? widget;
  const DataUpdateMessage({
    this.sessionId,
    required this.key,
    this.value,
    this.display,
    this.widget,
  });
}

class HistoryMessage extends ServerBroadcast {
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

class SubscribeAckMessage extends ServerBroadcast {
  const SubscribeAckMessage();
}
