import 'package:app/models/log_entry.dart';
import 'package:app/models/server_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ServerMessage.fromJson', () {
    // ── Test 1: ack ──

    test('type ack parses ackIds', () {
      final msg = ServerMessage.fromJson({
        'type': 'ack',
        'ack_ids': ['id-1', 'id-2'],
      });

      expect(msg.type, ServerMessageType.ack);
      expect(msg.ackIds, ['id-1', 'id-2']);
    });

    // ── Test 2: error ──

    test('type error parses errorCode, errorMessage, errorEntryId', () {
      final msg = ServerMessage.fromJson({
        'type': 'error',
        'error_code': 'INVALID_FORMAT',
        'error_message': 'bad payload',
        'error_entry_id': 'e-bad',
      });

      expect(msg.type, ServerMessageType.error);
      expect(msg.errorCode, 'INVALID_FORMAT');
      expect(msg.errorMessage, 'bad payload');
      expect(msg.errorEntryId, 'e-bad');
    });

    // ── Test 3: log ──

    test('type log parses nested entry', () {
      final msg = ServerMessage.fromJson({
        'type': 'log',
        'entry': {
          'id': 'e1',
          'timestamp': '2026-02-07T12:00:00Z',
          'session_id': 'sess-1',
          'severity': 'info',
          'type': 'text',
          'text': 'hello',
        },
      });

      expect(msg.type, ServerMessageType.log);
      expect(msg.entry, isNotNull);
      expect(msg.entry!.id, 'e1');
      expect(msg.entry!.text, 'hello');
    });

    // ── Test 4: logs ──

    test('type logs parses nested entries list', () {
      final msg = ServerMessage.fromJson({
        'type': 'logs',
        'entries': [
          {
            'id': 'e1',
            'timestamp': '2026-02-07T12:00:00Z',
            'session_id': 'sess-1',
            'severity': 'info',
            'type': 'text',
          },
          {
            'id': 'e2',
            'timestamp': '2026-02-07T12:01:00Z',
            'session_id': 'sess-1',
            'severity': 'warning',
            'type': 'text',
          },
        ],
      });

      expect(msg.type, ServerMessageType.logs);
      expect(msg.entries, hasLength(2));
      expect(msg.entries![0].id, 'e1');
      expect(msg.entries![1].id, 'e2');
    });

    // ── Test 5: rpc_request ──

    test('type rpc_request parses rpcId, rpcMethod, rpcArgs', () {
      final msg = ServerMessage.fromJson({
        'type': 'rpc_request',
        'rpc_id': 'rpc-1',
        'rpc_method': 'getState',
        'rpc_args': {'key': 'theme'},
      });

      expect(msg.type, ServerMessageType.rpcRequest);
      expect(msg.rpcId, 'rpc-1');
      expect(msg.rpcMethod, 'getState');
      expect(msg.rpcArgs, {'key': 'theme'});
    });

    // ── Test 6: rpc_response ──

    test('type rpc_response parses rpcId, rpcResponse, rpcError', () {
      final msg = ServerMessage.fromJson({
        'type': 'rpc_response',
        'rpc_id': 'rpc-1',
        'rpc_response': {'value': 'dark'},
        'rpc_error': null,
      });

      expect(msg.type, ServerMessageType.rpcResponse);
      expect(msg.rpcId, 'rpc-1');
      expect(msg.rpcResponse, {'value': 'dark'});
      expect(msg.rpcError, isNull);
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

      expect(msg.type, ServerMessageType.sessionList);
      expect(msg.sessions, hasLength(1));
      expect(msg.sessions![0].sessionId, 'sess-1');
      expect(msg.sessions![0].application.name, 'App1');
      expect(msg.sessions![0].logCount, 42);
    });

    // ── Test 8: session_update ──

    test(
      'type session_update parses sessionId, sessionAction, application',
      () {
        final msg = ServerMessage.fromJson({
          'type': 'session_update',
          'session_id': 'sess-1',
          'session_action': 'start',
          'application': {'name': 'MyApp', 'version': '1.0.0'},
        });

        expect(msg.type, ServerMessageType.sessionUpdate);
        expect(msg.sessionId, 'sess-1');
        expect(msg.sessionAction, SessionAction.start);
        expect(msg.application, isNotNull);
        expect(msg.application!.name, 'MyApp');
        expect(msg.application!.version, '1.0.0');
      },
    );

    // ── Test 9: state_snapshot ──

    test('type state_snapshot parses state map', () {
      final msg = ServerMessage.fromJson({
        'type': 'state_snapshot',
        'state': {'theme': 'dark', 'locale': 'en'},
      });

      expect(msg.type, ServerMessageType.stateSnapshot);
      expect(msg.state, {'theme': 'dark', 'locale': 'en'});
    });

    // ── Test 10: history ──

    test('type history parses historyEntries, hasMore, cursor, queryId', () {
      final msg = ServerMessage.fromJson({
        'type': 'history',
        'query_id': 'q1',
        'history_entries': [
          {
            'id': 'e1',
            'timestamp': '2026-02-07T12:00:00Z',
            'session_id': 'sess-1',
            'severity': 'info',
            'type': 'text',
          },
        ],
        'has_more': true,
        'cursor': 'next-page',
      });

      expect(msg.type, ServerMessageType.history);
      expect(msg.queryId, 'q1');
      expect(msg.historyEntries, hasLength(1));
      expect(msg.hasMore, isTrue);
      expect(msg.cursor, 'next-page');
    });

    // ── Test 11: subscribe_ack ──

    test('type subscribe_ack parses', () {
      final msg = ServerMessage.fromJson({'type': 'subscribe_ack'});

      expect(msg.type, ServerMessageType.subscribeAck);
    });
  });

  group('parseServerMessageType', () {
    test('unknown type defaults to error', () {
      expect(parseServerMessageType('unknown'), ServerMessageType.error);
    });
  });

  group('SessionInfo', () {
    // ── Test 12: SessionInfo.fromJson round-trip ──

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
