import 'package:app/models/log_entry.dart';
import 'package:app/theme/theme.dart';
import 'package:app/widgets/renderers/custom/http_request_renderer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_helpers.dart';

LogEntry _httpEntry({
  String method = 'GET',
  String url = 'https://api.example.com/data',
  int? status,
  int? durationMs,
  bool isError = false,
}) {
  return makeTestEntry(
    type: LogType.custom,
    customType: 'http_request',
    customData: {
      'method': method,
      'url': url,
      'status': ?status,
      'duration_ms': ?durationMs,
      'is_error': isError,
    },
  );
}

void main() {
  group('HttpRequestRenderer', () {
    testWidgets('renders method badge and URL', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: createLoggerTheme(),
          home: Scaffold(
            body: HttpRequestRenderer(
              entry: _httpEntry(method: 'POST', url: '/api/users'),
            ),
          ),
        ),
      );

      expect(find.text('POST'), findsOneWidget);
      expect(find.text('/api/users'), findsOneWidget);
    });

    testWidgets('renders status code', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: createLoggerTheme(),
          home: Scaffold(
            body: HttpRequestRenderer(
              entry: _httpEntry(status: 200, durationMs: 42),
            ),
          ),
        ),
      );

      expect(find.text('200'), findsOneWidget);
      expect(find.text('42ms'), findsOneWidget);
    });

    testWidgets('renders error state for invalid data', (tester) async {
      final entry = makeTestEntry(
        type: LogType.custom,
        customType: 'http_request',
        customData: 'not_a_map',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: createLoggerTheme(),
          home: Scaffold(body: HttpRequestRenderer(entry: entry)),
        ),
      );

      expect(find.text('[http_request: invalid data]'), findsOneWidget);
    });

    testWidgets('expands details on tap', (tester) async {
      final entry = makeTestEntry(
        type: LogType.custom,
        customType: 'http_request',
        customData: {
          'method': 'GET',
          'url': '/api',
          'status': 200,
          'request_headers': {'Authorization': 'Bearer token'},
          'response_body': '{"ok":true}',
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: createLoggerTheme(),
          home: Scaffold(body: HttpRequestRenderer(entry: entry)),
        ),
      );

      // Details not visible initially
      expect(find.text('Request Headers'), findsNothing);

      // Tap to expand
      await tester.tap(find.text('GET'));
      await tester.pumpAndSettle();

      expect(find.text('Request Headers'), findsOneWidget);
      expect(find.text('Response Body'), findsOneWidget);
    });

    testWidgets('renders 500 status with error color', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: createLoggerTheme(),
          home: Scaffold(
            body: HttpRequestRenderer(entry: _httpEntry(status: 500)),
          ),
        ),
      );

      expect(find.text('500'), findsOneWidget);
    });
  });
}
