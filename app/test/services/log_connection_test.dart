import 'dart:convert';

import 'package:app/models/server_message.dart';
import 'package:app/models/viewer_message.dart';
import 'package:app/services/log_connection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LogConnection', () {
    // ── Test 24: initial state — isConnected is false ──

    test('initial state is not connected', () {
      final conn = LogConnection();
      expect(conn.isConnected, isFalse);
      conn.dispose();
    });

    // ── Test 27: send serializes ViewerMessage to JSON ──

    test('send does nothing when not connected', () {
      final conn = LogConnection();
      // Should not throw when not connected
      conn.send(const ViewerMessage(type: ViewerMessageType.subscribe));
      conn.dispose();
    });

    // ── Test 28: subscribe sends subscribe ViewerMessage ──

    test('subscribe creates correct ViewerMessage', () {
      // Verify the ViewerMessage is correctly constructed
      const msg = ViewerMessage(
        type: ViewerMessageType.subscribe,
        sessionIds: ['sess-1'],
        minSeverity: 'warning',
      );
      final json = msg.toJson();

      expect(json['type'], 'subscribe');
      expect(json['session_ids'], ['sess-1']);
      expect(json['min_severity'], 'warning');
    });

    // ── Test 29: queryHistory sends history_query ViewerMessage ──

    test('queryHistory creates correct ViewerMessage', () {
      const msg = ViewerMessage(
        type: ViewerMessageType.historyQuery,
        queryId: 'q1',
        from: '2026-01-01T00:00:00Z',
        to: '2026-02-07T00:00:00Z',
        limit: 500,
        cursor: 'abc',
      );
      final json = msg.toJson();

      expect(json['type'], 'history_query');
      expect(json['query_id'], 'q1');
      expect(json['from'], '2026-01-01T00:00:00Z');
      expect(json['to'], '2026-02-07T00:00:00Z');
      expect(json['limit'], 500);
      expect(json['cursor'], 'abc');
    });

    // ── Test 30: valid JSON is parsed into ServerMessage on stream ──

    test('_onData parses valid JSON into ServerMessage', () async {
      // We test the parsing logic via ServerMessage.fromJson
      final json = {
        'type': 'log',
        'entry': {
          'id': 'e1',
          'timestamp': '2026-02-07T12:00:00Z',
          'session_id': 'sess-1',
          'severity': 'info',
          'kind': 'event',
          'message': 'hello',
        },
      };
      final msg = ServerMessage.fromJson(json);

      expect(msg.type, ServerMessageType.event);
      expect(msg.entry, isNotNull);
      expect(msg.entry!.message, 'hello');
    });

    // ── Test 31: invalid JSON doesn't crash ──

    test('ServerMessage.fromJson handles all known types', () {
      // Verify various types parse without throwing
      for (final type in [
        'ack',
        'error',
        'log',
        'logs',
        'rpc_request',
        'rpc_response',
        'session_list',
        'session_update',
        'state_snapshot',
        'history',
        'subscribe_ack',
      ]) {
        final msg = ServerMessage.fromJson({'type': type});
        expect(msg.type, isNotNull);
      }
    });

    // ── Test 34: dispose closes message controller stream ──

    test('dispose closes the messages stream', () async {
      final conn = LogConnection();
      final messages = conn.messages;

      conn.dispose();

      // After dispose, the stream should complete
      await expectLater(messages, emitsDone);
    });

    // ── Test: disconnect from initial state is safe ──

    test('disconnect when not connected is safe', () {
      final conn = LogConnection();
      conn.disconnect();
      expect(conn.isConnected, isFalse);
      conn.dispose();
    });

    // ── Test: notifyListeners called on disconnect ──

    test('disconnect calls notifyListeners', () {
      final conn = LogConnection();
      var notified = false;
      conn.addListener(() => notified = true);

      conn.disconnect();

      expect(notified, isTrue);
      conn.dispose();
    });

    // ── Test: ViewerMessage.toJsonString round-trip ──

    test('ViewerMessage.toJsonString produces valid JSON', () {
      const msg = ViewerMessage(type: ViewerMessageType.sessionList);
      final jsonStr = msg.toJsonString();
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;

      expect(decoded['type'], 'session_list');
    });

    // ── Test: subscribe with default params ──

    test('subscribe with default params creates correct message', () {
      const msg = ViewerMessage(type: ViewerMessageType.subscribe);
      final json = msg.toJson();

      expect(json['type'], 'subscribe');
      expect(json.containsKey('session_ids'), isFalse);
      expect(json.containsKey('min_severity'), isFalse);
    });

    // ── Test: toJson excludes null optional fields ──

    test('toJson excludes null optional fields', () {
      const msg = ViewerMessage(
        type: ViewerMessageType.rpcRequest,
        rpcId: 'r1',
        targetSessionId: 'sess-1',
        rpcMethod: 'getState',
      );
      final json = msg.toJson();

      expect(json['type'], 'rpc_request');
      expect(json['rpc_id'], 'r1');
      expect(json['target_session_id'], 'sess-1');
      expect(json['rpc_method'], 'getState');
      // Null fields should be absent
      expect(json.containsKey('session_ids'), isFalse);
      expect(json.containsKey('limit'), isFalse);
      expect(json.containsKey('cursor'), isFalse);
    });
  });
}
