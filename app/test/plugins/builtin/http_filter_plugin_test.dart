import 'package:app/models/log_entry.dart';
import 'package:app/plugins/builtin/http_filter_plugin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ─── Helpers ─────────────────────────────────────────────────────────

LogEntry _httpEntry({
  String method = 'GET',
  String url = '/api/test',
  int? status,
  int? durationMs,
  bool isError = false,
  String? requestId,
}) {
  final data = <String, dynamic>{
    'method': method,
    'url': url,
  };
  if (status != null) data['status'] = status;
  if (durationMs != null) data['duration_ms'] = durationMs;
  if (isError) data['is_error'] = true;
  if (requestId != null) data['request_id'] = requestId;
  return LogEntry(
    id: 'h1',
    timestamp: '2026-01-01T00:00:00Z',
    sessionId: 's1',
    kind: EntryKind.event,
    severity: Severity.info,
    widget: WidgetPayload(type: 'http_request', data: data),
  );
}

LogEntry _plainEntry() => LogEntry(
  id: 'p1',
  timestamp: '2026-01-01T00:00:00Z',
  sessionId: 's1',
  kind: EntryKind.event,
  severity: Severity.info,
  message: 'not http',
);

void main() {
  late HttpFilterPlugin plugin;

  setUp(() {
    plugin = HttpFilterPlugin();
  });

  group('HttpFilterPlugin identity', () {
    test('has correct id', () {
      expect(plugin.id, 'dev.logger.http-filter');
    });

    test('has correct name', () {
      expect(plugin.name, 'HTTP Filter');
    });

    test('has correct version', () {
      expect(plugin.version, '1.0.0');
    });

    test('is enabled by default', () {
      expect(plugin.enabled, isTrue);
    });

    test('filterLabel is HTTP', () {
      expect(plugin.filterLabel, 'HTTP');
    });

    test('filterIcon is http', () {
      expect(plugin.filterIcon, Icons.http);
    });
  });

  group('manifest', () {
    test('types contains filter', () {
      expect(plugin.manifest.types, contains('filter'));
    });

    test('id matches plugin id', () {
      expect(plugin.manifest.id, plugin.id);
    });
  });

  group('matches — basics', () {
    test('returns false for non-http entry', () {
      expect(plugin.matches(_plainEntry(), 'http:error'), isFalse);
    });

    test('returns false for non-http query prefix', () {
      expect(plugin.matches(_httpEntry(), 'status=200'), isFalse);
    });

    test('returns false for unknown expression', () {
      expect(plugin.matches(_httpEntry(), 'http:nope'), isFalse);
    });
  });

  group('matches — http:slow', () {
    test('matches when duration >= 1000ms', () {
      expect(
        plugin.matches(_httpEntry(durationMs: 1000), 'http:slow'),
        isTrue,
      );
    });

    test('does not match when duration < 1000ms', () {
      expect(
        plugin.matches(_httpEntry(durationMs: 500), 'http:slow'),
        isFalse,
      );
    });

    test('does not match when duration is null', () {
      expect(plugin.matches(_httpEntry(), 'http:slow'), isFalse);
    });
  });

  group('matches — http:error', () {
    test('matches is_error flag', () {
      expect(
        plugin.matches(_httpEntry(isError: true), 'http:error'),
        isTrue,
      );
    });

    test('matches status >= 400', () {
      expect(
        plugin.matches(_httpEntry(status: 404), 'http:error'),
        isTrue,
      );
      expect(
        plugin.matches(_httpEntry(status: 500), 'http:error'),
        isTrue,
      );
    });

    test('does not match status < 400 without error flag', () {
      expect(
        plugin.matches(_httpEntry(status: 200), 'http:error'),
        isFalse,
      );
    });
  });

  group('matches — http:status=', () {
    test('matches exact status', () {
      expect(
        plugin.matches(_httpEntry(status: 404), 'http:status=404'),
        isTrue,
      );
    });

    test('does not match different status', () {
      expect(
        plugin.matches(_httpEntry(status: 200), 'http:status=404'),
        isFalse,
      );
    });

    test('matches status class with xxx pattern', () {
      expect(
        plugin.matches(_httpEntry(status: 503), 'http:status=5xx'),
        isTrue,
      );
      expect(
        plugin.matches(_httpEntry(status: 404), 'http:status=5xx'),
        isFalse,
      );
    });

    test('returns false when status is null', () {
      expect(plugin.matches(_httpEntry(), 'http:status=200'), isFalse);
    });
  });

  group('matches — http:method=', () {
    test('matches exact method (case-insensitive)', () {
      expect(
        plugin.matches(_httpEntry(method: 'POST'), 'http:method=post'),
        isTrue,
      );
    });

    test('does not match different method', () {
      expect(
        plugin.matches(_httpEntry(method: 'GET'), 'http:method=POST'),
        isFalse,
      );
    });
  });

  group('matches — http:url~', () {
    test('matches partial URL', () {
      expect(
        plugin.matches(
          _httpEntry(url: '/api/v2/users'),
          'http:url~users',
        ),
        isTrue,
      );
    });

    test('case-insensitive URL match', () {
      expect(
        plugin.matches(
          _httpEntry(url: '/API/Users'),
          'http:url~api/users',
        ),
        isTrue,
      );
    });

    test('does not match absent pattern', () {
      expect(
        plugin.matches(_httpEntry(url: '/api/test'), 'http:url~missing'),
        isFalse,
      );
    });
  });

  group('matches — http:request_id=', () {
    test('matches exact request_id', () {
      expect(
        plugin.matches(
          _httpEntry(requestId: 'abc-123'),
          'http:request_id=abc-123',
        ),
        isTrue,
      );
    });

    test('does not match different request_id', () {
      expect(
        plugin.matches(
          _httpEntry(requestId: 'abc-123'),
          'http:request_id=xyz',
        ),
        isFalse,
      );
    });
  });

  group('getSuggestions', () {
    test('returns static suggestions when query is empty', () {
      final suggestions = plugin.getSuggestions('', []);
      expect(suggestions, contains('http:error'));
      expect(suggestions, contains('http:slow'));
      expect(suggestions, contains('http:status='));
      expect(suggestions, contains('http:method='));
    });

    test('includes dynamic status suggestions from entries', () {
      final entries = [_httpEntry(status: 404), _httpEntry(status: 200)];
      final suggestions = plugin.getSuggestions('', entries);
      expect(suggestions, contains('http:status=404'));
      expect(suggestions, contains('http:status=200'));
    });

    test('includes dynamic method suggestions from entries', () {
      final entries = [_httpEntry(method: 'DELETE')];
      final suggestions = plugin.getSuggestions('', entries);
      expect(suggestions, contains('http:method=DELETE'));
    });

    test('filters suggestions by partial query', () {
      final suggestions = plugin.getSuggestions('http:err', []);
      expect(suggestions, contains('http:error'));
      expect(suggestions, isNot(contains('http:slow')));
    });
  });
}
