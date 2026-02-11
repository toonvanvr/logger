import 'package:app/models/log_entry.dart';
import 'package:app/plugins/builtin/http_filter_plugin.dart';
import 'package:app/plugins/builtin/http_request_plugin.dart';
import 'package:app/widgets/renderers/custom/http/http_collapsed_row.dart';
import 'package:app/widgets/renderers/custom/http/http_timing_bar.dart';
import 'package:app/widgets/renderers/custom/http/http_utils.dart';
import 'package:app/widgets/renderers/custom/http_request_renderer.dart';
import 'package:app/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers.dart';

// ─── Fixtures ────────────────────────────────────────────────────────

LogEntry _httpEntry({
  String method = 'GET',
  String url = 'https://api.example.com/api/v1/users',
  int? status,
  String? statusText,
  int? durationMs,
  int? ttfbMs,
  bool isError = false,
  Map<String, dynamic>? requestHeaders,
  Map<String, dynamic>? responseHeaders,
  String? requestBody,
  String? responseBody,
  int? requestBodySize,
  int? responseBodySize,
  String? contentType,
  String? requestId,
  String? startedAt,
}) {
  return makeTestEntry(
    kind: EntryKind.event,
    widget: WidgetPayload(
      type: 'http_request',
      data: {
        'method': method,
        'url': url,
        if (status != null) 'status': status,
        if (statusText != null) 'status_text': statusText,
        if (durationMs != null) 'duration_ms': durationMs,
        if (ttfbMs != null) 'ttfb_ms': ttfbMs,
        'is_error': isError,
        if (requestHeaders != null) 'request_headers': requestHeaders,
        if (responseHeaders != null) 'response_headers': responseHeaders,
        if (requestBody != null) 'request_body': requestBody,
        if (responseBody != null) 'response_body': responseBody,
        if (requestBodySize != null) 'request_body_size': requestBodySize,
        if (responseBodySize != null) 'response_body_size': responseBodySize,
        if (contentType != null) 'content_type': contentType,
        if (requestId != null) 'request_id': requestId,
        if (startedAt != null) 'started_at': startedAt,
      },
    ),
  );
}

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: createLoggerTheme(),
    home: Scaffold(body: child),
  );
}

// ─── Tests ───────────────────────────────────────────────────────────

void main() {
  // ═══════════════════════════════════════════════════════════════════
  // Plugin identity
  // ═══════════════════════════════════════════════════════════════════

  group('HttpRequestRendererPlugin identity', () {
    late HttpRequestRendererPlugin plugin;

    setUp(() {
      plugin = HttpRequestRendererPlugin();
    });

    test('has correct id', () {
      expect(plugin.id, 'dev.logger.http-request-renderer');
    });

    test('has correct name', () {
      expect(plugin.name, 'HTTP Request Renderer');
    });

    test('has correct version', () {
      expect(plugin.version, '1.0.0');
    });

    test('customTypes contains http_request', () {
      expect(plugin.customTypes, contains('http_request'));
    });

    test('is enabled by default', () {
      expect(plugin.enabled, isTrue);
    });

    test('manifest types contains renderer', () {
      expect(plugin.manifest.types, contains('renderer'));
    });

    test('manifest id matches plugin id', () {
      expect(plugin.manifest.id, plugin.id);
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // Plugin buildPreview
  // ═══════════════════════════════════════════════════════════════════

  group('HttpRequestRendererPlugin buildPreview', () {
    late HttpRequestRendererPlugin plugin;

    setUp(() {
      plugin = HttpRequestRendererPlugin();
    });

    testWidgets('returns widget for valid data', (tester) async {
      final data = {
        'method': 'GET',
        'url': 'https://api.example.com/users',
        'status': 200,
        'duration_ms': 45,
      };
      final preview = plugin.buildPreview(data);
      expect(preview, isNotNull);
      expect(preview, isA<Widget>());
    });

    test('returns null when method is missing', () {
      final data = {'url': '/api/users'};
      expect(plugin.buildPreview(data), isNull);
    });

    test('returns null when url is missing', () {
      final data = {'method': 'GET'};
      expect(plugin.buildPreview(data), isNull);
    });

    test('returns null for empty data', () {
      expect(plugin.buildPreview({}), isNull);
    });

    testWidgets('preview includes PENDING for null status', (tester) async {
      final data = {
        'method': 'POST',
        'url': '/api/orders',
      };
      final preview = plugin.buildPreview(data);
      expect(preview, isA<Text>());
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // Plugin buildRenderer
  // ═══════════════════════════════════════════════════════════════════

  group('HttpRequestRendererPlugin buildRenderer', () {
    late HttpRequestRendererPlugin plugin;

    setUp(() {
      plugin = HttpRequestRendererPlugin();
    });

    testWidgets('returns HttpRequestRenderer widget', (tester) async {
      final entry = _httpEntry(method: 'GET', url: '/api/users', status: 200);
      final data = entry.widget!.data;

      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) => plugin.buildRenderer(context, data, entry),
          ),
        ),
      );

      expect(find.byType(HttpRequestRenderer), findsOneWidget);
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // HttpFilterPlugin identity
  // ═══════════════════════════════════════════════════════════════════

  group('HttpFilterPlugin identity', () {
    late HttpFilterPlugin filter;

    setUp(() {
      filter = HttpFilterPlugin();
    });

    test('has correct id', () {
      expect(filter.id, 'dev.logger.http-filter');
    });

    test('has correct name', () {
      expect(filter.name, 'HTTP Filter');
    });

    test('has correct version', () {
      expect(filter.version, '1.0.0');
    });

    test('filterLabel is HTTP', () {
      expect(filter.filterLabel, 'HTTP');
    });

    test('filterIcon is http', () {
      expect(filter.filterIcon, Icons.http);
    });

    test('is enabled by default', () {
      expect(filter.enabled, isTrue);
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // HttpFilterPlugin matching
  // ═══════════════════════════════════════════════════════════════════

  group('HttpFilterPlugin matches', () {
    late HttpFilterPlugin filter;

    setUp(() {
      filter = HttpFilterPlugin();
    });

    test('http:status=200 matches exact status', () {
      final entry = _httpEntry(status: 200);
      expect(filter.matches(entry, 'http:status=200'), isTrue);
    });

    test('http:status=200 does not match 404', () {
      final entry = _httpEntry(status: 404);
      expect(filter.matches(entry, 'http:status=200'), isFalse);
    });

    test('http:status=5xx matches 500', () {
      final entry = _httpEntry(status: 500);
      expect(filter.matches(entry, 'http:status=5xx'), isTrue);
    });

    test('http:status=5xx matches 503', () {
      final entry = _httpEntry(status: 503);
      expect(filter.matches(entry, 'http:status=5xx'), isTrue);
    });

    test('http:status=5xx does not match 404', () {
      final entry = _httpEntry(status: 404);
      expect(filter.matches(entry, 'http:status=5xx'), isFalse);
    });

    test('http:status=4xx matches 429', () {
      final entry = _httpEntry(status: 429);
      expect(filter.matches(entry, 'http:status=4xx'), isTrue);
    });

    test('http:status=2xx matches 201', () {
      final entry = _httpEntry(status: 201);
      expect(filter.matches(entry, 'http:status=2xx'), isTrue);
    });

    test('http:method=GET matches case-insensitive', () {
      final entry = _httpEntry(method: 'get');
      expect(filter.matches(entry, 'http:method=GET'), isTrue);
    });

    test('http:method=POST matches POST', () {
      final entry = _httpEntry(method: 'POST');
      expect(filter.matches(entry, 'http:method=POST'), isTrue);
    });

    test('http:method=GET does not match POST', () {
      final entry = _httpEntry(method: 'POST');
      expect(filter.matches(entry, 'http:method=GET'), isFalse);
    });

    test('http:url~users matches URL substring', () {
      final entry = _httpEntry(url: 'https://api.example.com/api/v1/users');
      expect(filter.matches(entry, 'http:url~users'), isTrue);
    });

    test('http:url~orders does not match /users URL', () {
      final entry = _httpEntry(url: 'https://api.example.com/api/v1/users');
      expect(filter.matches(entry, 'http:url~orders'), isFalse);
    });

    test('http:slow matches duration >= 1000ms', () {
      final entry = _httpEntry(durationMs: 1200);
      expect(filter.matches(entry, 'http:slow'), isTrue);
    });

    test('http:slow matches exactly 1000ms', () {
      final entry = _httpEntry(durationMs: 1000);
      expect(filter.matches(entry, 'http:slow'), isTrue);
    });

    test('http:slow does not match 999ms', () {
      final entry = _httpEntry(durationMs: 999);
      expect(filter.matches(entry, 'http:slow'), isFalse);
    });

    test('http:slow does not match null duration', () {
      final entry = _httpEntry();
      expect(filter.matches(entry, 'http:slow'), isFalse);
    });

    test('http:error matches is_error=true', () {
      final entry = _httpEntry(isError: true);
      expect(filter.matches(entry, 'http:error'), isTrue);
    });

    test('http:error matches status >= 400', () {
      final entry = _httpEntry(status: 500);
      expect(filter.matches(entry, 'http:error'), isTrue);
    });

    test('http:error matches status 404', () {
      final entry = _httpEntry(status: 404);
      expect(filter.matches(entry, 'http:error'), isTrue);
    });

    test('http:error does not match 200', () {
      final entry = _httpEntry(status: 200);
      expect(filter.matches(entry, 'http:error'), isFalse);
    });

    test('http:request_id=abc matches exact request_id', () {
      final entry = _httpEntry(requestId: 'abc');
      expect(filter.matches(entry, 'http:request_id=abc'), isTrue);
    });

    test('http:request_id=abc does not match different id', () {
      final entry = _httpEntry(requestId: 'xyz');
      expect(filter.matches(entry, 'http:request_id=abc'), isFalse);
    });

    test('non-http: query returns false', () {
      final entry = _httpEntry(status: 200);
      expect(filter.matches(entry, 'tagname'), isFalse);
    });

    test('returns false for non-http_request widget type', () {
      final entry = makeTestEntry(
        kind: EntryKind.event,
        widget: const WidgetPayload(type: 'chart', data: {}),
      );
      expect(filter.matches(entry, 'http:status=200'), isFalse);
    });

    test('returns false for entry without widget', () {
      final entry = makeTestEntry(kind: EntryKind.event);
      expect(filter.matches(entry, 'http:status=200'), isFalse);
    });

    test('http:status returns false for null status', () {
      final entry = _httpEntry();
      expect(filter.matches(entry, 'http:status=200'), isFalse);
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // HttpFilterPlugin getSuggestions
  // ═══════════════════════════════════════════════════════════════════

  group('HttpFilterPlugin getSuggestions', () {
    late HttpFilterPlugin filter;

    setUp(() {
      filter = HttpFilterPlugin();
    });

    test('returns static suggestions for empty query', () {
      final suggestions = filter.getSuggestions('', []);
      expect(suggestions, contains('http:error'));
      expect(suggestions, contains('http:slow'));
      expect(suggestions, contains('http:status='));
      expect(suggestions, contains('http:method='));
      expect(suggestions, contains('http:url~'));
      expect(suggestions, contains('http:request_id='));
    });

    test('returns dynamic suggestions from entries', () {
      final entries = [
        _httpEntry(method: 'POST', status: 201),
        _httpEntry(method: 'DELETE', status: 404),
      ];
      final suggestions = filter.getSuggestions('', entries);
      expect(suggestions, contains('http:status=201'));
      expect(suggestions, contains('http:status=404'));
      expect(suggestions, contains('http:method=POST'));
      expect(suggestions, contains('http:method=DELETE'));
    });

    test('filters suggestions by partial query', () {
      final suggestions = filter.getSuggestions('http:err', []);
      expect(suggestions, contains('http:error'));
      expect(suggestions, isNot(contains('http:slow')));
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // Renderer widget tests
  // ═══════════════════════════════════════════════════════════════════

  group('HttpRequestRenderer', () {
    testWidgets('renders method badge and URL for success', (tester) async {
      await tester.pumpWidget(
        _wrap(
          HttpRequestRenderer(
            entry: _httpEntry(
              method: 'GET',
              url: '/api/users/profile',
              status: 200,
              durationMs: 45,
            ),
          ),
        ),
      );

      expect(find.text('GET'), findsOneWidget);
      expect(find.text('/api/users/profile'), findsOneWidget);
      expect(find.text('200'), findsOneWidget);
      expect(find.text('45ms'), findsOneWidget);
    });

    testWidgets('renders PENDING state when status is null', (tester) async {
      await tester.pumpWidget(
        _wrap(
          HttpRequestRenderer(
            entry: _httpEntry(method: 'POST', url: '/api/orders'),
          ),
        ),
      );

      expect(find.text('POST'), findsOneWidget);
      expect(find.text('PENDING'), findsOneWidget);
    });

    testWidgets('renders error hint row for 500+ status', (tester) async {
      await tester.pumpWidget(
        _wrap(
          HttpRequestRenderer(
            entry: _httpEntry(
              method: 'POST',
              url: '/api/orders',
              status: 503,
              responseBody: '{"error":"Connection pool exhausted"}',
            ),
          ),
        ),
      );

      expect(find.text('503'), findsOneWidget);
      expect(
        find.text('{"error":"Connection pool exhausted"}'),
        findsOneWidget,
      );
    });

    testWidgets('renders error state for invalid data', (tester) async {
      final entry = makeTestEntry(kind: EntryKind.event);

      await tester.pumpWidget(
        _wrap(HttpRequestRenderer(entry: entry)),
      );

      expect(find.text('[http_request: invalid data]'), findsOneWidget);
    });

    testWidgets('expands details on chevron tap', (tester) async {
      await tester.pumpWidget(
        _wrap(
          HttpRequestRenderer(
            entry: _httpEntry(
              method: 'GET',
              url: 'https://api.example.com/api/v1/users?page=1',
              status: 200,
              durationMs: 150,
              requestHeaders: {
                'Authorization': 'Bearer token123',
                'Accept': 'application/json',
              },
              responseBody: '{"users":[]}',
            ),
          ),
        ),
      );

      // Details not visible initially
      expect(find.text('Request Headers (2)'), findsNothing);

      // Tap to expand via the collapsed row
      await tester.tap(find.text('GET'));
      await tester.pumpAndSettle();

      expect(find.text('Request Headers (2)'), findsOneWidget);
      expect(find.text('Response Body'), findsOneWidget);
    });

    testWidgets('collapse hides expanded sections', (tester) async {
      await tester.pumpWidget(
        _wrap(
          HttpRequestRenderer(
            entry: _httpEntry(
              method: 'GET',
              url: '/api',
              status: 200,
              durationMs: 100,
              requestHeaders: {'Accept': 'application/json'},
            ),
          ),
        ),
      );

      // Expand
      await tester.tap(find.text('GET'));
      await tester.pumpAndSettle();
      expect(find.text('Request Headers (1)'), findsOneWidget);

      // Collapse
      await tester.tap(find.text('GET'));
      await tester.pumpAndSettle();
      expect(find.text('Request Headers (1)'), findsNothing);
    });

    testWidgets('renders timing bar when duration_ms present',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          HttpRequestRenderer(
            entry: _httpEntry(
              method: 'GET',
              url: '/api/slow',
              status: 200,
              durationMs: 1200,
              ttfbMs: 900,
            ),
          ),
        ),
      );

      // Expand to show timing
      await tester.tap(find.text('GET'));
      await tester.pumpAndSettle();

      expect(find.byType(HttpTimingBar), findsOneWidget);
      expect(find.text('1200ms'), findsOneWidget);
    });

    testWidgets('renders status text alongside status code', (tester) async {
      await tester.pumpWidget(
        _wrap(
          HttpRequestRenderer(
            entry: _httpEntry(
              method: 'GET',
              url: '/api/users',
              status: 200,
              statusText: 'OK',
              durationMs: 42,
            ),
          ),
        ),
      );

      expect(find.text('200 OK'), findsOneWidget);
    });

    testWidgets('renders 500 status', (tester) async {
      await tester.pumpWidget(
        _wrap(
          HttpRequestRenderer(
            entry: _httpEntry(status: 500, durationMs: 1200),
          ),
        ),
      );

      expect(find.text('500'), findsOneWidget);
    });

    testWidgets('renders TIMEOUT for error with no status', (tester) async {
      await tester.pumpWidget(
        _wrap(
          HttpRequestRenderer(
            entry: _httpEntry(isError: true, durationMs: 30000),
          ),
        ),
      );

      expect(find.text('TIMEOUT'), findsOneWidget);
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // HttpCollapsedRow widget tests
  // ═══════════════════════════════════════════════════════════════════

  group('HttpCollapsedRow', () {
    testWidgets('renders method pill and URL path', (tester) async {
      await tester.pumpWidget(
        _wrap(
          HttpCollapsedRow(
            data: const {
              'method': 'DELETE',
              'url': '/api/v1/users/42',
              'status': 204,
              'duration_ms': 12,
            },
            expanded: false,
            onToggle: () {},
          ),
        ),
      );

      expect(find.text('DELETE'), findsOneWidget);
      expect(find.text('/api/v1/users/42'), findsOneWidget);
      expect(find.text('204'), findsOneWidget);
      expect(find.text('12ms'), findsOneWidget);
    });

    testWidgets('shows dash for null duration', (tester) async {
      await tester.pumpWidget(
        _wrap(
          HttpCollapsedRow(
            data: const {
              'method': 'GET',
              'url': '/api/health',
            },
            expanded: false,
            onToggle: () {},
          ),
        ),
      );

      expect(find.text('—'), findsOneWidget);
    });

    testWidgets('formats duration as seconds when >= 1000', (tester) async {
      await tester.pumpWidget(
        _wrap(
          HttpCollapsedRow(
            data: const {
              'method': 'GET',
              'url': '/api/slow',
              'status': 200,
              'duration_ms': 2500,
            },
            expanded: false,
            onToggle: () {},
          ),
        ),
      );

      expect(find.text('2.5s'), findsOneWidget);
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // HttpTimingBar
  // ═══════════════════════════════════════════════════════════════════

  group('HttpTimingBar', () {
    testWidgets('renders single bar without ttfb', (tester) async {
      await tester.pumpWidget(
        _wrap(const HttpTimingBar(durationMs: 200)),
      );

      expect(find.text('200ms'), findsOneWidget);
    });

    testWidgets('renders segmented bar with ttfb', (tester) async {
      await tester.pumpWidget(
        _wrap(const HttpTimingBar(durationMs: 1000, ttfbMs: 800)),
      );

      expect(find.text('1000ms'), findsOneWidget);
      // TTFB percentage label
      expect(find.text('800ms (80%)'), findsOneWidget);
      // Transfer percentage label
      expect(find.text('200ms (20%)'), findsOneWidget);
    });

    testWidgets('renders nothing for null duration', (tester) async {
      await tester.pumpWidget(
        _wrap(const HttpTimingBar()),
      );

      expect(find.byType(HttpTimingBar), findsOneWidget);
      // SizedBox.shrink renders but has no children
      expect(find.text('ms'), findsNothing);
    });

    testWidgets('renders nothing for zero duration', (tester) async {
      await tester.pumpWidget(
        _wrap(const HttpTimingBar(durationMs: 0)),
      );

      expect(find.text('0ms'), findsNothing);
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // http_utils.dart
  // ═══════════════════════════════════════════════════════════════════

  group('formatBytes', () {
    test('formats null as empty string', () {
      expect(formatBytes(null), '');
    });

    test('formats bytes < 1024', () {
      expect(formatBytes(512), '512 B');
    });

    test('formats kilobytes', () {
      expect(formatBytes(2048), '2.0 KB');
    });

    test('formats megabytes', () {
      expect(formatBytes(1048576), '1.0 MB');
    });

    test('formats fractional kilobytes', () {
      expect(formatBytes(1536), '1.5 KB');
    });

    test('formats zero bytes', () {
      expect(formatBytes(0), '0 B');
    });
  });

  group('classifyStatus', () {
    test('returns PENDING for null status without error', () {
      final (_, label) = classifyStatus(null, false);
      expect(label, 'PENDING');
    });

    test('returns TIMEOUT for null status with error', () {
      final (_, label) = classifyStatus(null, true);
      expect(label, 'TIMEOUT');
    });

    test('returns info color for 2xx', () {
      final (color, label) = classifyStatus(200, false);
      expect(label, '200');
      expect(color, isNotNull);
    });

    test('includes status text when provided', () {
      final (_, label) = classifyStatus(200, false, statusText: 'OK');
      expect(label, '200 OK');
    });

    test('returns warning color for 4xx', () {
      final (_, label) = classifyStatus(404, false, statusText: 'Not Found');
      expect(label, '404 Not Found');
    });

    test('returns error color for 5xx', () {
      final (_, label) = classifyStatus(500, false);
      expect(label, '500');
    });

    test('returns secondary color for 3xx', () {
      final (_, label) = classifyStatus(301, false, statusText: 'Moved');
      expect(label, '301 Moved');
    });

    test('returns syntaxUrl color for 101', () {
      final (_, label) = classifyStatus(101, false, statusText: 'UPGRADE');
      expect(label, '101 UPGRADE');
    });
  });

  group('methodColor', () {
    test('returns syntaxKey for GET', () {
      expect(methodColor('GET'), isNotNull);
    });

    test('returns syntaxString for POST', () {
      expect(methodColor('POST'), isNotNull);
    });

    test('GET and POST have different colors', () {
      expect(methodColor('GET'), isNot(equals(methodColor('POST'))));
    });
  });

  group('durationColor', () {
    test('returns muted for null', () {
      expect(durationColor(null), isNotNull);
    });

    test('returns secondary for < 200ms', () {
      final color = durationColor(100);
      expect(color, isNotNull);
    });

    test('returns syntaxNumber for 200-999ms', () {
      final color = durationColor(500);
      expect(color, isNotNull);
    });

    test('returns error color for >= 1000ms', () {
      final color = durationColor(1500);
      expect(color, isNotNull);
    });

    test('fast and slow have different colors', () {
      expect(durationColor(50), isNot(equals(durationColor(2000))));
    });
  });

  group('generateCurl', () {
    test('produces valid curl command for GET', () {
      final curl = generateCurl({
        'method': 'GET',
        'url': 'https://api.example.com/users',
      });
      expect(curl, contains('curl'));
      expect(curl, contains('-X GET'));
      expect(curl, contains('https://api.example.com/users'));
    });

    test('includes headers with -H flag', () {
      final curl = generateCurl({
        'method': 'GET',
        'url': 'https://api.example.com/data',
        'request_headers': {'Authorization': 'Bearer token123'},
      });
      expect(curl, contains('-H'));
      expect(curl, contains('Authorization: Bearer token123'));
    });

    test('includes body with -d flag', () {
      final curl = generateCurl({
        'method': 'POST',
        'url': 'https://api.example.com/users',
        'request_body': '{"name":"Alice"}',
      });
      expect(curl, contains('-d'));
      expect(curl, contains('{"name":"Alice"}'));
    });

    test('handles empty data gracefully', () {
      final curl = generateCurl({});
      expect(curl, contains('curl'));
      expect(curl, contains('-X GET'));
    });
  });

  group('parseUrl', () {
    test('parses full URL with scheme and host', () {
      final parsed = parseUrl('https://api.example.com/api/v1/users');
      expect(parsed.scheme, 'https');
      expect(parsed.host, 'api.example.com');
      expect(parsed.path, '/api/v1/users');
    });

    test('parses URL with query parameters', () {
      final parsed = parseUrl('https://api.example.com/search?q=test&page=1');
      expect(parsed.path, '/search');
      expect(parsed.queryParams, {'q': 'test', 'page': '1'});
    });

    test('parses path-only URL', () {
      final parsed = parseUrl('/api/v1/users');
      expect(parsed.scheme, isNull);
      expect(parsed.host, isNull);
      expect(parsed.path, '/api/v1/users');
    });

    test('handles invalid URL gracefully', () {
      final parsed = parseUrl(':::invalid');
      // Should not throw
      expect(parsed.path, isNotEmpty);
    });
  });

  group('decodeUrlForDisplay', () {
    test('decodes percent-encoded string', () {
      expect(
        decodeUrlForDisplay('/api/users/John%20Doe'),
        '/api/users/John Doe',
      );
    });

    test('returns original for already-decoded string', () {
      expect(decodeUrlForDisplay('/api/users'), '/api/users');
    });

    test('handles invalid encoding gracefully', () {
      // Should not throw — returns original
      final result = decodeUrlForDisplay('%E0%A4%A');
      expect(result, isNotEmpty);
    });
  });
}
