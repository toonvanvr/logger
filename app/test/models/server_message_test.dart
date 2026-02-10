import 'package:app/models/log_entry.dart';
import 'package:app/models/server_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ServerMessage.fromJson', () {
    // ── Test 1: ack ──

    test('type ack parses ackIds', () {
      final msg = ServerMessage.fromJson({
        'type': 'ack',
        'ids': ['id-1', 'id-2'],
      });

      expect(msg, isA<AckMessage>());
      final ack = msg as AckMessage;
      expect(ack.ackIds, ['id-1', 'id-2']);
    });

    // ── Test 2: error ──

    test('type error parses errorCode, errorMessage, errorEntryId', () {
      final msg = ServerMessage.fromJson({
        'type': 'error',
        'code': 'INVALID_FORMAT',
        'message': 'bad payload',
        'entry_id': 'e-bad',
      });

      expect(msg, isA<ErrorMessage>());
      final error = msg as ErrorMessage;
      expect(error.errorCode, 'INVALID_FORMAT');
      expect(error.errorMessage, 'bad payload');
      expect(error.errorEntryId, 'e-bad');
    });

    // ── Test 3: event (single entry) ──

    test('type event parses nested entry', () {
      final msg = ServerMessage.fromJson({
        'type': 'event',
        'entry': {
          'id': 'e1',
          'timestamp': '2026-02-07T12:00:00Z',
          'session_id': 'sess-1',
          'kind': 'event',
          'severity': 'info',
          'message': 'hello',
        },
      });

      expect(msg, isA<EventMessage>());
      final event = msg as EventMessage;
      expect(event.entry.id, 'e1');
      expect(event.entry.message, 'hello');
    });

    // ── Test 4: event_batch removed (no server equivalent) ──

    test('type event_batch falls through to unknown', () {
      final msg = ServerMessage.fromJson({'type': 'event_batch'});
      expect(msg, isA<ErrorMessage>());
    });

    // ── Test 5: rpc_request ──

    test('type rpc_request parses rpcId, rpcMethod, rpcArgs', () {
      final msg = ServerMessage.fromJson({
        'type': 'rpc_request',
        'rpc_id': 'rpc-1',
        'method': 'getState',
        'args': {'key': 'theme'},
      });

      expect(msg, isA<RpcRequestMessage>());
      final rpc = msg as RpcRequestMessage;
      expect(rpc.rpcId, 'rpc-1');
      expect(rpc.rpcMethod, 'getState');
      expect(rpc.rpcArgs, {'key': 'theme'});
    });

    // ── Test 6: rpc_response ──

    test('type rpc_response parses rpcId, rpcResponse, rpcError', () {
      final msg = ServerMessage.fromJson({
        'type': 'rpc_response',
        'rpc_id': 'rpc-1',
        'result': {'value': 'dark'},
        'error': null,
      });

      expect(msg, isA<RpcResponseMessage>());
      final rpc = msg as RpcResponseMessage;
      expect(rpc.rpcId, 'rpc-1');
      expect(rpc.rpcResponse, {'value': 'dark'});
      expect(rpc.rpcError, isNull);
    });

    // ── Test 7: session_list ──

    test('type session_list parses sessions array', () {
      final msg = ServerMessage.fromJson({
        'type': 'session_list',
        'sessions': [
          {
            'session_id': 'sess-1',
            'application': {'name': 'App1'},
            'started_at': '2026-02-07T12:00:00Z',
            'last_heartbeat': '2026-02-07T12:01:00Z',
            'is_active': true,
            'log_count': 42,
            'color_index': 0,
          },
        ],
      });

      expect(msg, isA<SessionListMessage>());
      final list = msg as SessionListMessage;
      expect(list.sessions, hasLength(1));
      expect(list.sessions[0].sessionId, 'sess-1');
      expect(list.sessions[0].application.name, 'App1');
      expect(list.sessions[0].logCount, 42);
    });

    // ── Test 8: session_update ──

    test(
      'type session_update parses sessionId, sessionAction, application',
      () {
        final msg = ServerMessage.fromJson({
          'type': 'session_update',
          'session_id': 'sess-1',
          'action': 'start',
          'application': {'name': 'MyApp', 'version': '1.0.0'},
        });

        expect(msg, isA<SessionUpdateMessage>());
        final update = msg as SessionUpdateMessage;
        expect(update.sessionId, 'sess-1');
        expect(update.sessionAction, SessionAction.start);
        expect(update.application, isNotNull);
        expect(update.application!.name, 'MyApp');
        expect(update.application!.version, '1.0.0');
      },
    );

    // ── Test 9: data_snapshot ──

    test('type data_snapshot parses data map with DataState values', () {
      final msg = ServerMessage.fromJson({
        'type': 'data_snapshot',
        'session_id': 's1',
        'data': {
          'theme': {'value': 'dark', 'display': 'shelf'},
          'locale': {'value': 'en'},
        },
      });

      expect(msg, isA<DataSnapshotMessage>());
      final snapshot = msg as DataSnapshotMessage;
      expect(snapshot.sessionId, 's1');
      expect(snapshot.data['theme']!.value, 'dark');
      expect(snapshot.data['theme']!.display, DisplayLocation.shelf);
      expect(snapshot.data['locale']!.value, 'en');
      expect(snapshot.data['locale']!.display, DisplayLocation.defaultLoc);
    });

    // ── Test 10: data_update ──

    test('type data_update parses dataKey, dataValue, dataDisplay, sessionId', () {
      final msg = ServerMessage.fromJson({
        'type': 'data_update',
        'session_id': 's1',
        'key': 'theme',
        'value': 'dark',
        'display': 'shelf',
      });

      expect(msg, isA<DataUpdateMessage>());
      final update = msg as DataUpdateMessage;
      expect(update.sessionId, 's1');
      expect(update.dataKey, 'theme');
      expect(update.dataValue, 'dark');
      expect(update.dataDisplay, DisplayLocation.shelf);
    });

    // ── Test 11: data_update with widget ──

    test('type data_update parses dataWidget', () {
      final msg = ServerMessage.fromJson({
        'type': 'data_update',
        'key': 'cpu',
        'value': 87.5,
        'widget': {'type': 'gauge', 'max': 100},
      });

      expect(msg, isA<DataUpdateMessage>());
      final update = msg as DataUpdateMessage;
      expect(update.dataWidget, isNotNull);
      expect(update.dataWidget!.type, 'gauge');
      expect(update.dataWidget!.data['max'], 100);
    });

    // ── Test 12: history ──

    test('type history parses entries, hasMore, cursor, queryId', () {
      final msg = ServerMessage.fromJson({
        'type': 'history',
        'query_id': 'q1',
        'entries': [
          {
            'id': 'e1',
            'timestamp': '2026-02-07T12:00:00Z',
            'session_id': 'sess-1',
            'kind': 'event',
            'severity': 'info',
          },
        ],
        'has_more': true,
        'cursor': 'next-page',
      });

      expect(msg, isA<HistoryMessage>());
      final history = msg as HistoryMessage;
      expect(history.queryId, 'q1');
      expect(history.entries, hasLength(1));
      expect(history.hasMore, isTrue);
      expect(history.cursor, 'next-page');
    });

    // ── Test 13: subscribe_ack ──

    test('type subscribe_ack parses', () {
      final msg = ServerMessage.fromJson({'type': 'subscribe_ack'});

      expect(msg, isA<SubscribeAckMessage>());
    });

    // ── Test 14: malformed JSON ──

    test('event with missing entry returns ErrorMessage', () {
      final msg = ServerMessage.fromJson({'type': 'event'});
      expect(msg, isA<ErrorMessage>());
    });

    test('unknown type returns ErrorMessage', () {
      final msg = ServerMessage.fromJson({'type': 'unknown_stuff'});
      expect(msg, isA<ErrorMessage>());
    });
  });

  group('SessionInfo', () {
    test('fromJson parses all required fields', () {
      final info = SessionInfo.fromJson({
        'session_id': 'sess-1',
        'application': {
          'name': 'TestApp',
          'version': '3.0.0',
          'environment': 'dev',
        },
        'started_at': '2026-02-07T12:00:00Z',
        'last_heartbeat': '2026-02-07T12:05:00Z',
        'is_active': false,
        'log_count': 100,
        'color_index': 5,
      });

      expect(info.sessionId, 'sess-1');
      expect(info.application.name, 'TestApp');
      expect(info.application.version, '3.0.0');
      expect(info.application.environment, 'dev');
      expect(info.startedAt, '2026-02-07T12:00:00Z');
      expect(info.lastHeartbeat, '2026-02-07T12:05:00Z');
      expect(info.isActive, isFalse);
      expect(info.logCount, 100);
      expect(info.colorIndex, 5);
    });
  });
}
