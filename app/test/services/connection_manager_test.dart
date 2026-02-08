import 'package:app/models/server_connection.dart';
import 'package:app/services/connection_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ConnectionManager', () {
    // ── Initial state ──

    test('initial state has empty connections', () {
      final mgr = ConnectionManager();
      expect(mgr.connections, isEmpty);
      expect(mgr.activeCount, 0);
      expect(mgr.isConnected, isFalse);
      mgr.dispose();
    });

    // ── addConnection ──

    test('addConnection returns non-empty id', () {
      final mgr = ConnectionManager();
      final id = mgr.addConnection('ws://localhost:8082', connect: false);

      expect(id, isNotEmpty);
      mgr.dispose();
    });

    test('addConnection adds entry to connections map', () {
      final mgr = ConnectionManager();
      final id = mgr.addConnection('ws://localhost:8082', connect: false);

      expect(mgr.connections.containsKey(id), isTrue);
      expect(mgr.connections[id]!.url, 'ws://localhost:8082');
      mgr.dispose();
    });

    test('addConnection with label stores label', () {
      final mgr = ConnectionManager();
      final id = mgr.addConnection(
        'ws://localhost:8082',
        label: 'Dev Server',
        connect: false,
      );

      expect(mgr.connections[id]!.label, 'Dev Server');
      mgr.dispose();
    });

    test('addConnection calls notifyListeners', () {
      final mgr = ConnectionManager();
      var notified = false;
      mgr.addListener(() => notified = true);

      mgr.addConnection('ws://localhost:8082', connect: false);

      expect(notified, isTrue);
      mgr.dispose();
    });

    // ── removeConnection ──

    test('removeConnection removes entry from map', () {
      final mgr = ConnectionManager();
      final id = mgr.addConnection('ws://localhost:8082', connect: false);

      mgr.removeConnection(id);

      expect(mgr.connections.containsKey(id), isFalse);
      expect(mgr.connections, isEmpty);
      mgr.dispose();
    });

    test('removeConnection calls notifyListeners', () {
      final mgr = ConnectionManager();
      final id = mgr.addConnection('ws://localhost:8082', connect: false);
      var notified = false;
      mgr.addListener(() => notified = true);

      mgr.removeConnection(id);

      expect(notified, isTrue);
      mgr.dispose();
    });

    // ── toggleConnection ──

    test('toggleConnection toggles enabled flag', () {
      final mgr = ConnectionManager();
      final id = mgr.addConnection('ws://localhost:8082', connect: false);

      // Initially enabled
      expect(mgr.connections[id]!.enabled, isTrue);

      mgr.toggleConnection(id);

      expect(mgr.connections[id]!.enabled, isFalse);
      mgr.dispose();
    });

    test('toggleConnection on unknown id is safe', () {
      final mgr = ConnectionManager();
      mgr.toggleConnection('nonexistent');
      expect(mgr.connections, isEmpty);
      mgr.dispose();
    });

    // ── dispose ──

    test('dispose does not throw', () {
      final mgr = ConnectionManager();
      mgr.addConnection('ws://localhost:8082', connect: false);
      mgr.addConnection('ws://localhost:9090', connect: false);

      expect(() => mgr.dispose(), returnsNormally);
    });

    test('messages stream completes after dispose', () async {
      final mgr = ConnectionManager();
      final messages = mgr.messages;

      mgr.dispose();

      await expectLater(messages, emitsDone);
    });
  });

  group('ServerConnection', () {
    // ── displayLabel ──

    test('displayLabel returns label when set', () {
      final conn = ServerConnection(
        id: '1',
        url: 'ws://localhost:8082',
        label: 'My Server',
      );
      expect(conn.displayLabel, 'My Server');
    });

    test('displayLabel returns host when label is null', () {
      final conn = ServerConnection(id: '1', url: 'ws://example.com:8082');
      expect(conn.displayLabel, 'example.com');
    });

    test('displayLabel returns host when label is empty', () {
      final conn = ServerConnection(
        id: '1',
        url: 'ws://example.com:8082',
        label: '',
      );
      expect(conn.displayLabel, 'example.com');
    });

    // ── isActive ──

    test('isActive is true only when connected', () {
      final connected = ServerConnection(
        id: '1',
        url: 'ws://localhost:8082',
        state: ServerConnectionState.connected,
      );
      final disconnected = ServerConnection(
        id: '2',
        url: 'ws://localhost:8082',
        state: ServerConnectionState.disconnected,
      );

      expect(connected.isActive, isTrue);
      expect(disconnected.isActive, isFalse);
    });

    // ── copyWith ──

    test('copyWith preserves unchanged fields', () {
      final conn = ServerConnection(
        id: '1',
        url: 'ws://localhost:8082',
        label: 'Test',
        enabled: true,
      );
      final copy = conn.copyWith(enabled: false);

      expect(copy.id, '1');
      expect(copy.url, 'ws://localhost:8082');
      expect(copy.label, 'Test');
      expect(copy.enabled, isFalse);
    });

    test('copyWith replaces specified fields', () {
      final conn = ServerConnection(
        id: '1',
        url: 'ws://localhost:8082',
        state: ServerConnectionState.disconnected,
        retryCount: 0,
      );
      final copy = conn.copyWith(
        state: ServerConnectionState.reconnecting,
        retryCount: 3,
        lastError: 'timeout',
      );

      expect(copy.state, ServerConnectionState.reconnecting);
      expect(copy.retryCount, 3);
      expect(copy.lastError, 'timeout');
    });

    // ── defaults ──

    test('defaults are correct', () {
      final conn = ServerConnection(id: '1', url: 'ws://localhost:8082');

      expect(conn.enabled, isTrue);
      expect(conn.autoReconnect, isTrue);
      expect(conn.colorIndex, 0);
      expect(conn.state, ServerConnectionState.disconnected);
      expect(conn.retryCount, 0);
      expect(conn.lastError, isNull);
    });
  });
}
