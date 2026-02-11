/// Dart equivalent of the v2 ViewerMessage schema.
library;

import 'dart:convert';

// ─── Viewer Message (sealed hierarchy) ───────────────────────────────

/// Base class for messages sent from the viewer to the server.
///
/// Each subclass corresponds to a single message type and carries only
/// the fields relevant to that type. Prefixed with `Viewer` to avoid
/// name collisions with [ServerBroadcast] subclasses.
sealed class ViewerMessage {
  const ViewerMessage();

  Map<String, dynamic> toJson();

  String toJsonString() => jsonEncode(toJson());
}

class ViewerSubscribeMessage extends ViewerMessage {
  final List<String>? sessionIds;
  final String? minSeverity;
  final List<String>? tags;
  final String? textFilter;

  const ViewerSubscribeMessage({
    this.sessionIds,
    this.minSeverity,
    this.tags,
    this.textFilter,
  });

  @override
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'type': 'subscribe'};
    if (sessionIds != null) map['session_ids'] = sessionIds;
    if (minSeverity != null) map['min_severity'] = minSeverity;
    if (tags != null) map['tags'] = tags;
    if (textFilter != null) map['text_filter'] = textFilter;
    return map;
  }
}

class ViewerUnsubscribeMessage extends ViewerMessage {
  final List<String>? sessionIds;

  const ViewerUnsubscribeMessage({this.sessionIds});

  @override
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'type': 'unsubscribe'};
    if (sessionIds != null) map['session_ids'] = sessionIds;
    return map;
  }
}

class ViewerHistoryQueryMessage extends ViewerMessage {
  final String? queryId;
  final String? from;
  final String? to;
  final String? sessionId;
  final String? search;
  final int? limit;
  final String? cursor;

  /// Where to query: 'buffer', 'store', or 'auto' (default).
  final String? source;

  const ViewerHistoryQueryMessage({
    this.queryId,
    this.from,
    this.to,
    this.sessionId,
    this.search,
    this.limit,
    this.cursor,
    this.source,
  });

  @override
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'type': 'history'};
    if (queryId != null) map['query_id'] = queryId;
    if (from != null) map['from'] = from;
    if (to != null) map['to'] = to;
    if (sessionId != null) map['session_id'] = sessionId;
    if (search != null) map['search'] = search;
    if (limit != null) map['limit'] = limit;
    if (cursor != null) map['cursor'] = cursor;
    if (source != null) map['source'] = source;
    return map;
  }
}

class ViewerRpcRequestMessage extends ViewerMessage {
  final String? rpcId;
  final String? targetSessionId;
  final String? method;
  final dynamic args;

  const ViewerRpcRequestMessage({
    this.rpcId,
    this.targetSessionId,
    this.method,
    this.args,
  });

  @override
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'type': 'rpc_request'};
    if (rpcId != null) map['rpc_id'] = rpcId;
    if (targetSessionId != null) map['target_session_id'] = targetSessionId;
    if (method != null) map['method'] = method;
    if (args != null) map['args'] = args;
    return map;
  }
}

class ViewerSessionListMessage extends ViewerMessage {
  const ViewerSessionListMessage();

  @override
  Map<String, dynamic> toJson() => {'type': 'session_list'};
}

class ViewerDataQueryMessage extends ViewerMessage {
  final String? sessionId;

  const ViewerDataQueryMessage({this.sessionId});

  @override
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'type': 'data_query'};
    if (sessionId != null) map['session_id'] = sessionId;
    return map;
  }
}
