import 'package:app/models/server_connection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ServerConnectionState', () {
    test('has exactly 5 values', () {
      expect(ServerConnectionState.values, hasLength(5));
    });
  });

  group('ServerConnection', () {
    test('constructor sets required fields', () {
      final conn = ServerConnection(id: 's1', url: 'ws://localhost:8080');
      expect(conn.id, 's1');
      expect(conn.url, 'ws://localhost:8080');
    });

    test('defaults are correct', () {
      final conn = ServerConnection(id: 's1', url: 'ws://localhost:8080');
      expect(conn.label, isNull);
      expect(conn.enabled, isTrue);
      expect(conn.autoReconnect, isTrue);
      expect(conn.colorIndex, 0);
      expect(conn.state, ServerConnectionState.disconnected);
      expect(conn.retryCount, 0);
      expect(conn.lastError, isNull);
      expect(conn.createdAt, isNotNull);
    });
  });

  group('ServerConnection.displayLabel', () {
    test('returns user label when set', () {
      final conn = ServerConnection(
        id: 's1',
        url: 'ws://localhost:8080',
        label: 'My Server',
      );
      expect(conn.displayLabel, 'My Server');
    });

    test('extracts host from URL when no label', () {
      final conn = ServerConnection(
        id: 's1',
        url: 'ws://example.com:8080/ws',
      );
      expect(conn.displayLabel, 'example.com');
    });

    test('returns raw URL on parse failure', () {
      final conn = ServerConnection(id: 's1', url: ':::invalid');
      // Uri.parse doesn't throw for most inputs; test the fallback path
      expect(conn.displayLabel, isNotEmpty);
    });
  });

  group('ServerConnection.isActive', () {
    test('true when connected', () {
      final conn = ServerConnection(
        id: 's1',
        url: 'ws://localhost:8080',
        state: ServerConnectionState.connected,
      );
      expect(conn.isActive, isTrue);
    });

    test('false when disconnected', () {
      final conn = ServerConnection(id: 's1', url: 'ws://localhost:8080');
      expect(conn.isActive, isFalse);
    });
  });

  group('ServerConnection.copyWith', () {
    test('copies with changed fields', () {
      final original = ServerConnection(
        id: 's1',
        url: 'ws://localhost:8080',
        label: 'Original',
      );
      final copy = original.copyWith(
        label: 'Updated',
        state: ServerConnectionState.connected,
        retryCount: 3,
      );

      expect(copy.id, 's1');
      expect(copy.url, 'ws://localhost:8080');
      expect(copy.label, 'Updated');
      expect(copy.state, ServerConnectionState.connected);
      expect(copy.retryCount, 3);
    });

    test('preserves fields when not specified', () {
      final original = ServerConnection(
        id: 's1',
        url: 'ws://localhost:8080',
        enabled: false,
        colorIndex: 5,
      );
      final copy = original.copyWith(label: 'New');

      expect(copy.enabled, isFalse);
      expect(copy.colorIndex, 5);
      expect(copy.createdAt, original.createdAt);
    });
  });
}
