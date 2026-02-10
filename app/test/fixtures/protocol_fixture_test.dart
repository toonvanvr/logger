import 'dart:convert';
import 'dart:io';

import 'package:app/models/log_entry.dart';
import 'package:app/models/server_message.dart';
import 'package:app/models/viewer_message.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads a JSON fixture from packages/shared/test/fixtures/.
Map<String, dynamic> loadFixture(String name) {
  // Flutter test cwd is app/
  final file = File('${Directory.current.path}/../packages/shared/test/fixtures/$name');
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

void main() {
  group('ServerBroadcast fixture conformance', () {
    test('broadcast_event.json', () {
      final json = loadFixture('broadcast_event.json');
      final msg = ServerMessage.fromJson(json);
      expect(msg, isA<EventMessage>());
      final event = msg as EventMessage;
      expect(event.entry.id, equals('fix-001'));
      expect(event.entry.severity, equals(Severity.info));
      expect(event.entry.message, equals('Test fixture event'));
      expect(event.entry.tag, equals('test'));
      expect(event.entry.exception, isNotNull);
      expect(event.entry.exception!.type, equals('Error'));
      expect(event.entry.exception!.stackTrace, isA<String>());
      expect(event.entry.exception!.source, equals('test-suite'));
      expect(event.entry.exception!.handled, isTrue);
      expect(event.entry.exception!.inner, isNull);
      expect(event.entry.labels, equals({'env': 'test'}));
    });

    test('broadcast_data_update.json', () {
      final json = loadFixture('broadcast_data_update.json');
      final msg = ServerMessage.fromJson(json);
      expect(msg, isA<DataUpdateMessage>());
      final update = msg as DataUpdateMessage;
      expect(update.sessionId, equals('s1'));
      expect(update.dataKey, equals('db_pool'));
      expect(update.dataValue, isA<Map>());
    });

    test('broadcast_data_snapshot.json', () {
      final json = loadFixture('broadcast_data_snapshot.json');
      final msg = ServerMessage.fromJson(json);
      expect(msg, isA<DataSnapshotMessage>());
      final snapshot = msg as DataSnapshotMessage;
      expect(snapshot.sessionId, equals('s1'));
      expect(snapshot.data.containsKey('key1'), isTrue);
      expect(snapshot.data['key1']!.value, equals('v1'));
    });

    test('broadcast_session_update.json', () {
      final json = loadFixture('broadcast_session_update.json');
      final msg = ServerMessage.fromJson(json);
      expect(msg, isA<SessionUpdateMessage>());
      final update = msg as SessionUpdateMessage;
      expect(update.sessionId, equals('s1'));
      expect(update.sessionAction, equals(SessionAction.start));
      expect(update.application, isNotNull);
      expect(update.application!.name, equals('demo'));
    });

    test('broadcast_session_list.json', () {
      final json = loadFixture('broadcast_session_list.json');
      final msg = ServerMessage.fromJson(json);
      expect(msg, isA<SessionListMessage>());
      final list = msg as SessionListMessage;
      expect(list.sessions, hasLength(1));
      expect(list.sessions.first.sessionId, equals('s1'));
      expect(list.sessions.first.application.name, equals('demo'));
      expect(list.sessions.first.isActive, isTrue);
      expect(list.sessions.first.logCount, equals(42));
    });

    test('broadcast_history.json', () {
      final json = loadFixture('broadcast_history.json');
      final msg = ServerMessage.fromJson(json);
      expect(msg, isA<HistoryMessage>());
      final history = msg as HistoryMessage;
      expect(history.queryId, equals('q1'));
      expect(history.entries, hasLength(1));
      expect(history.entries.first.id, equals('fix-hist-001'));
      expect(history.hasMore, isFalse);
      expect(history.source, equals('buffer'));
    });

    test('broadcast_error.json', () {
      final json = loadFixture('broadcast_error.json');
      final msg = ServerMessage.fromJson(json);
      expect(msg, isA<ErrorMessage>());
      final error = msg as ErrorMessage;
      expect(error.errorCode, equals('RATE_LIMIT'));
      expect(error.errorMessage, equals('Too many requests'));
    });

    test('broadcast_ack.json', () {
      final json = loadFixture('broadcast_ack.json');
      final msg = ServerMessage.fromJson(json);
      expect(msg, isA<AckMessage>());
      expect((msg as AckMessage).ackIds, equals(['id1', 'id2']));
    });

    test('broadcast_rpc_request.json', () {
      final json = loadFixture('broadcast_rpc_request.json');
      final msg = ServerMessage.fromJson(json);
      expect(msg, isA<RpcRequestMessage>());
      final rpc = msg as RpcRequestMessage;
      expect(rpc.rpcId, equals('rpc1'));
      expect(rpc.rpcMethod, equals('getState'));
      expect(rpc.rpcArgs, isA<Map>());
    });

    test('broadcast_rpc_response.json', () {
      final json = loadFixture('broadcast_rpc_response.json');
      final msg = ServerMessage.fromJson(json);
      expect(msg, isA<RpcResponseMessage>());
      final rpc = msg as RpcResponseMessage;
      expect(rpc.rpcId, equals('rpc1'));
      expect(rpc.rpcResponse, isA<Map>());
      expect(rpc.rpcError, isNull);
    });

    test('broadcast_subscribe_ack.json', () {
      final json = loadFixture('broadcast_subscribe_ack.json');
      final msg = ServerMessage.fromJson(json);
      expect(msg, isA<SubscribeAckMessage>());
    });
  });

  group('ViewerCommand fixture conformance', () {
    test('command_subscribe.json round-trip', () {
      final json = loadFixture('command_subscribe.json');
      final msg = ViewerSubscribeMessage(
        sessionIds: (json['session_ids'] as List<dynamic>?)?.cast<String>(),
      );
      final output = msg.toJson();
      expect(output['type'], equals('subscribe'));
      expect(output['session_ids'], equals(json['session_ids']));
    });

    test('command_unsubscribe.json round-trip', () {
      final json = loadFixture('command_unsubscribe.json');
      final msg = ViewerUnsubscribeMessage(
        sessionIds: (json['session_ids'] as List<dynamic>?)?.cast<String>(),
      );
      final output = msg.toJson();
      expect(output['type'], equals('unsubscribe'));
      expect(output['session_ids'], equals(json['session_ids']));
    });

    test('command_history.json round-trip', () {
      final json = loadFixture('command_history.json');
      final msg = ViewerHistoryQueryMessage(
        queryId: json['query_id'] as String?,
        sessionId: json['session_id'] as String?,
        limit: json['limit'] as int?,
      );
      final output = msg.toJson();
      expect(output['type'], equals('history'));
      expect(output['query_id'], equals(json['query_id']));
      expect(output['session_id'], equals(json['session_id']));
      expect(output['limit'], equals(json['limit']));
    });
  });
}
