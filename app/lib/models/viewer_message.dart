/// Dart equivalent of the shared TypeScript ViewerMessage schema.
library;

import 'dart:convert';

// ─── Viewer Message Types ────────────────────────────────────────────

enum ViewerMessageType {
  subscribe,
  unsubscribe,
  historyQuery,
  rpcRequest,
  sessionList,
  stateQuery,
}

String _viewerMessageTypeToJson(ViewerMessageType type) {
  return switch (type) {
    ViewerMessageType.subscribe => 'subscribe',
    ViewerMessageType.unsubscribe => 'unsubscribe',
    ViewerMessageType.historyQuery => 'history_query',
    ViewerMessageType.rpcRequest => 'rpc_request',
    ViewerMessageType.sessionList => 'session_list',
    ViewerMessageType.stateQuery => 'state_query',
  };
}

// ─── Viewer Message ──────────────────────────────────────────────────

class ViewerMessage {
  final ViewerMessageType type;

  // subscribe / unsubscribe
  final List<String>? sessionIds;
  final String? minSeverity;
  final List<String>? sections;
  final String? textFilter;

  // history_query
  final String? queryId;
  final String? from;
  final String? to;
  final String? sessionId;
  final String? search;
  final int? limit;
  final String? cursor;

  /// Where to query: 'buffer', 'store', or 'auto' (default).
  final String? source;

  // rpc_request
  final String? rpcId;
  final String? targetSessionId;
  final String? rpcMethod;
  final dynamic rpcArgs;

  // state_query
  final String? stateSessionId;

  const ViewerMessage({
    required this.type,
    this.sessionIds,
    this.minSeverity,
    this.sections,
    this.textFilter,
    this.queryId,
    this.from,
    this.to,
    this.sessionId,
    this.search,
    this.limit,
    this.cursor,
    this.source,
    this.rpcId,
    this.targetSessionId,
    this.rpcMethod,
    this.rpcArgs,
    this.stateSessionId,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'type': _viewerMessageTypeToJson(type)};

    if (sessionIds != null) map['session_ids'] = sessionIds;
    if (minSeverity != null) map['min_severity'] = minSeverity;
    if (sections != null) map['sections'] = sections;
    if (textFilter != null) map['text_filter'] = textFilter;
    if (queryId != null) map['query_id'] = queryId;
    if (from != null) map['from'] = from;
    if (to != null) map['to'] = to;
    if (sessionId != null) map['session_id'] = sessionId;
    if (search != null) map['search'] = search;
    if (limit != null) map['limit'] = limit;
    if (cursor != null) map['cursor'] = cursor;
    if (source != null) map['source'] = source;
    if (rpcId != null) map['rpc_id'] = rpcId;
    if (targetSessionId != null) map['target_session_id'] = targetSessionId;
    if (rpcMethod != null) map['rpc_method'] = rpcMethod;
    if (rpcArgs != null) map['rpc_args'] = rpcArgs;
    if (stateSessionId != null) map['state_session_id'] = stateSessionId;

    return map;
  }

  String toJsonString() => jsonEncode(toJson());
}
