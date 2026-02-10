import 'dart:async';

import 'package:app/services/connection_manager.dart';
import 'package:app/services/uri_handler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UriHandler.handleUri', () {
    late ConnectionManager connectionManager;
    late String? capturedFilter;
    late String? capturedTab;
    late bool clearCalled;

    setUp(() {
      connectionManager = ConnectionManager();
      capturedFilter = null;
      capturedTab = null;
      clearCalled = false;
    });

    tearDown(() {
      connectionManager.dispose();
    });

    bool handle(String uri) {
      return UriHandler.handleUri(
        uri,
        connectionManager: connectionManager,
        onFilter: (q) => capturedFilter = q,
        onTab: (t) => capturedTab = t,
        onClear: () => clearCalled = true,
      );
    }

    test('returns false for non-logger scheme', () {
      expect(handle('https://example.com'), isFalse);
    });

    test('returns false for invalid URI', () {
      expect(
        UriHandler.handleUri(
          ':::invalid',
          connectionManager: connectionManager,
          onFilter: (_) {},
          onTab: (_) {},
          onClear: () {},
        ),
        isFalse,
      );
    });

    test('handles logger://open', () {
      expect(handle('logger://open'), isTrue);
    });

    test('handles logger://connect with host and port', () {
      // Wrap in runZonedGuarded so the async DNS lookup error from
      // WebSocketChannel.connect stays in the guarded zone.
      late bool result;
      runZonedGuarded(
        () {
          result = handle('logger://connect?host=myhost&port=9090');
        },
        (error, stack) {
          // Expected: DNS lookup failure for fake 'myhost' hostname
        },
      );
      expect(result, isTrue);
      expect(connectionManager.connections.length, 1);
      final conn = connectionManager.connections.values.first;
      expect(conn.url, 'ws://myhost:9090/api/v2/stream');
      expect(conn.label, 'myhost:9090');
    });

    test('handles logger://connect with defaults', () {
      late bool result;
      runZonedGuarded(
        () {
          result = handle('logger://connect');
        },
        (error, stack) {
          // Expected: connection error for localhost in test environment
        },
      );
      expect(result, isTrue);
      expect(connectionManager.connections.length, 1);
      final conn = connectionManager.connections.values.first;
      expect(conn.url, 'ws://localhost:8080/api/v2/stream');
    });

    test('handles logger://filter with query', () {
      final result = handle('logger://filter?query=state:cpu_usage');
      expect(result, isTrue);
      expect(capturedFilter, 'state:cpu_usage');
    });

    test('handles logger://filter with empty query', () {
      final result = handle('logger://filter');
      expect(result, isTrue);
      expect(capturedFilter, '');
    });

    test('handles logger://tab with name', () {
      final result = handle('logger://tab?name=frontend');
      expect(result, isTrue);
      expect(capturedTab, 'frontend');
    });

    test('handles logger://clear', () {
      final result = handle('logger://clear');
      expect(result, isTrue);
      expect(clearCalled, isTrue);
    });

    test('returns false for unknown host', () {
      expect(handle('logger://unknown'), isFalse);
    });
  });

  group('UriHandler.extractFromArgs', () {
    test('returns null for empty args', () {
      expect(UriHandler.extractFromArgs([]), isNull);
    });

    test('returns null when no logger:// arg', () {
      expect(UriHandler.extractFromArgs(['--verbose', 'foo']), isNull);
    });

    test('extracts logger:// URI from args', () {
      expect(
        UriHandler.extractFromArgs(['--debug', 'logger://open', '--flag']),
        'logger://open',
      );
    });

    test('returns first logger:// URI when multiple exist', () {
      expect(
        UriHandler.extractFromArgs([
          'logger://filter?query=test',
          'logger://open',
        ]),
        'logger://filter?query=test',
      );
    });
  });
}
