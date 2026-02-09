import 'dart:convert';

import 'package:app/models/viewer_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ViewerMessage.toJson', () {
    // ── Test 1: subscribe includes all fields ──

    test(
      'subscribe toJson includes sessionIds, minSeverity, tags, textFilter',
      () {
        const msg = ViewerMessage(
          type: ViewerMessageType.subscribe,
          sessionIds: ['sess-1', 'sess-2'],
          minSeverity: 'warning',
          tags: ['network', 'ui'],
          textFilter: 'error',
        );
        final json = msg.toJson();

        expect(json['type'], 'subscribe');
        expect(json['session_ids'], ['sess-1', 'sess-2']);
        expect(json['min_severity'], 'warning');
        expect(json['tags'], ['network', 'ui']);
        expect(json['text_filter'], 'error');
      },
    );

    // ── Test 2: unsubscribe toJson ──

    test('unsubscribe toJson', () {
      const msg = ViewerMessage(type: ViewerMessageType.unsubscribe);
      final json = msg.toJson();

      expect(json['type'], 'unsubscribe');
    });

    // ── Test 3: history_query with all fields ──

    test('history_query toJson with all fields', () {
      const msg = ViewerMessage(
        type: ViewerMessageType.historyQuery,
        queryId: 'q1',
        from: '2026-01-01T00:00:00Z',
        to: '2026-02-07T00:00:00Z',
        sessionId: 'sess-1',
        search: 'error',
        limit: 500,
        cursor: 'abc',
      );
      final json = msg.toJson();

      expect(json['type'], 'history_query');
      expect(json['query_id'], 'q1');
      expect(json['from'], '2026-01-01T00:00:00Z');
      expect(json['to'], '2026-02-07T00:00:00Z');
      expect(json['session_id'], 'sess-1');
      expect(json['search'], 'error');
      expect(json['limit'], 500);
      expect(json['cursor'], 'abc');
    });

    // ── Test 4: rpc_request with all fields ──

    test(
      'rpc_request toJson with targetSessionId, rpcId, rpcMethod, rpcArgs',
      () {
        const msg = ViewerMessage(
          type: ViewerMessageType.rpcRequest,
          targetSessionId: 'sess-1',
          rpcId: 'rpc-1',
          rpcMethod: 'getState',
          rpcArgs: {'key': 'theme'},
        );
        final json = msg.toJson();

        expect(json['type'], 'rpc_request');
        expect(json['target_session_id'], 'sess-1');
        expect(json['rpc_id'], 'rpc-1');
        expect(json['rpc_method'], 'getState');
        expect(json['rpc_args'], {'key': 'theme'});
      },
    );

    // ── Test 5: session_list toJson ──

    test('session_list toJson minimal', () {
      const msg = ViewerMessage(type: ViewerMessageType.sessionList);
      final json = msg.toJson();

      expect(json['type'], 'session_list');
    });

    // ── Test 6: data_query toJson ──

    test('data_query toJson with dataSessionId', () {
      const msg = ViewerMessage(
        type: ViewerMessageType.dataQuery,
        dataSessionId: 'sess-1',
      );
      final json = msg.toJson();

      expect(json['type'], 'data_query');
      expect(json['data_session_id'], 'sess-1');
    });

    // ── Test 7: excludes null optional fields ──

    test('toJson excludes null optional fields', () {
      const msg = ViewerMessage(type: ViewerMessageType.subscribe);
      final json = msg.toJson();

      expect(json.containsKey('session_ids'), isFalse);
      expect(json.containsKey('min_severity'), isFalse);
      expect(json.containsKey('tags'), isFalse);
      expect(json.containsKey('text_filter'), isFalse);
      expect(json.containsKey('query_id'), isFalse);
      expect(json.containsKey('from'), isFalse);
      expect(json.containsKey('to'), isFalse);
      expect(json.containsKey('session_id'), isFalse);
      expect(json.containsKey('search'), isFalse);
      expect(json.containsKey('limit'), isFalse);
      expect(json.containsKey('cursor'), isFalse);
      expect(json.containsKey('rpc_id'), isFalse);
      expect(json.containsKey('target_session_id'), isFalse);
      expect(json.containsKey('rpc_method'), isFalse);
      expect(json.containsKey('rpc_args'), isFalse);
      expect(json.containsKey('data_session_id'), isFalse);
    });
  });

  // ── Test 8: toJsonString ──

  test('toJsonString produces valid JSON string', () {
    const msg = ViewerMessage(
      type: ViewerMessageType.subscribe,
      sessionIds: ['sess-1'],
    );
    final jsonStr = msg.toJsonString();
    final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;

    expect(decoded['type'], 'subscribe');
    expect(decoded['session_ids'], ['sess-1']);
  });
}
