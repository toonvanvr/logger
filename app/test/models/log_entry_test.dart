import 'package:app/models/log_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LogEntry.fromJson', () {
    // ── Test 1: required fields (event kind) ──

    test('parses required fields for event kind', () {
      final entry = LogEntry.fromJson({
        'id': 'e1',
        'timestamp': '2026-02-07T12:00:00Z',
        'session_id': 'sess-1',
        'kind': 'event',
        'severity': 'warning',
      });

      expect(entry.id, 'e1');
      expect(entry.timestamp, '2026-02-07T12:00:00Z');
      expect(entry.sessionId, 'sess-1');
      expect(entry.kind, EntryKind.event);
      expect(entry.severity, Severity.warning);
    });

    // ── Test 2: event fields ──

    test('parses event-specific fields', () {
      final entry = LogEntry.fromJson({
        'id': 'e2',
        'timestamp': '2026-02-07T12:00:00Z',
        'session_id': 'sess-1',
        'kind': 'event',
        'severity': 'info',
        'message': 'hello world',
        'tag': 'network',
        'parent_id': 'p1',
        'group_id': 'g1',
        'prev_id': 'prev-1',
        'next_id': 'next-1',
        'replace': true,
        'generated_at': '2026-02-07T11:59:00Z',
        'sent_at': '2026-02-07T11:59:30Z',
      });

      expect(entry.message, 'hello world');
      expect(entry.tag, 'network');
      expect(entry.parentId, 'p1');
      expect(entry.groupId, 'g1');
      expect(entry.prevId, 'prev-1');
      expect(entry.nextId, 'next-1');
      expect(entry.replace, isTrue);
      expect(entry.generatedAt, '2026-02-07T11:59:00Z');
      expect(entry.sentAt, '2026-02-07T11:59:30Z');
    });

    // ── Test 3: nested ApplicationInfo (session kind) ──

    test('parses session kind with ApplicationInfo', () {
      final entry = LogEntry.fromJson({
        'id': 'e3',
        'timestamp': '2026-02-07T12:00:00Z',
        'session_id': 'sess-1',
        'kind': 'session',
        'severity': 'info',
        'session_action': 'start',
        'application': {
          'name': 'MyApp',
          'version': '1.2.3',
          'environment': 'production',
        },
        'metadata': {'os': 'linux'},
      });

      expect(entry.kind, EntryKind.session);
      expect(entry.sessionAction, SessionAction.start);
      expect(entry.application, isNotNull);
      expect(entry.application!.name, 'MyApp');
      expect(entry.application!.version, '1.2.3');
      expect(entry.application!.environment, 'production');
      expect(entry.metadata, {'os': 'linux'});
    });

    // ── Test 4: nested ExceptionData with cause chain ──

    test('parses nested ExceptionData with cause chain', () {
      final entry = LogEntry.fromJson({
        'id': 'e4',
        'timestamp': '2026-02-07T12:00:00Z',
        'session_id': 'sess-1',
        'kind': 'event',
        'severity': 'error',
        'exception': {
          'type': 'TypeError',
          'message': 'null is not an object',
          'stackTrace': [
            {
              'location': {'uri': 'app.dart', 'line': 10, 'column': 5},
              'isVendor': false,
            },
          ],
          'cause': {'type': 'RangeError', 'message': 'index out of range'},
        },
      });

      expect(entry.exception, isNotNull);
      expect(entry.exception!.type, 'TypeError');
      expect(entry.exception!.message, 'null is not an object');
      expect(entry.exception!.stackTrace, hasLength(1));
      expect(entry.exception!.stackTrace!.first.location.uri, 'app.dart');
      expect(entry.exception!.cause, isNotNull);
      expect(entry.exception!.cause!.type, 'RangeError');
      expect(entry.exception!.cause!.message, 'index out of range');
    });

    // ── Test 5: widget payload ──

    test('parses widget payload', () {
      final entry = LogEntry.fromJson({
        'id': 'e5',
        'timestamp': '2026-02-07T12:00:00Z',
        'session_id': 'sess-1',
        'kind': 'event',
        'severity': 'info',
        'widget': {
          'type': 'table',
          'columns': ['Name', 'Value'],
          'rows': [
            ['cpu', '87%'],
          ],
        },
      });

      expect(entry.widget, isNotNull);
      expect(entry.widget!.type, 'table');
      expect(entry.widget!.data['columns'], ['Name', 'Value']);
      expect(entry.widget!.data.containsKey('type'), isFalse);
    });

    // ── Test 6: nested IconRef ──

    test('parses nested IconRef', () {
      final entry = LogEntry.fromJson({
        'id': 'e6',
        'timestamp': '2026-02-07T12:00:00Z',
        'session_id': 'sess-1',
        'kind': 'event',
        'severity': 'info',
        'icon': {'icon': 'star', 'color': '#FFD700', 'size': 24.0},
      });

      expect(entry.icon, isNotNull);
      expect(entry.icon!.icon, 'star');
      expect(entry.icon!.color, '#FFD700');
      expect(entry.icon!.size, 24.0);
    });

    // ── Test 7: data kind with key/value/display ──

    test('parses data kind fields', () {
      final entry = LogEntry.fromJson({
        'id': 'e7',
        'timestamp': '2026-02-07T12:00:00Z',
        'session_id': 'sess-1',
        'kind': 'data',
        'severity': 'info',
        'key': 'theme',
        'value': 'dark',
        'override': false,
        'display': 'shelf',
      });

      expect(entry.kind, EntryKind.data);
      expect(entry.key, 'theme');
      expect(entry.value, 'dark');
      expect(entry.override_, isFalse);
      expect(entry.display, DisplayLocation.shelf);
    });

    // ── Test 8: labels ──

    test('parses labels as Map<String, String>', () {
      final entry = LogEntry.fromJson({
        'id': 'e8',
        'timestamp': '2026-02-07T12:00:00Z',
        'session_id': 'sess-1',
        'kind': 'event',
        'severity': 'info',
        'labels': {'env': 'prod', 'region': 'eu-west'},
      });

      expect(entry.labels, {'env': 'prod', 'region': 'eu-west'});
    });

    // ── Test 9: server-assigned receivedAt ──

    test('parses server-assigned receivedAt', () {
      final entry = LogEntry.fromJson({
        'id': 'e9',
        'timestamp': '2026-02-07T12:00:00Z',
        'session_id': 'sess-1',
        'kind': 'event',
        'severity': 'info',
        'received_at': '2026-02-07T12:00:01Z',
      });

      expect(entry.receivedAt, '2026-02-07T12:00:01Z');
    });

    // ── Test 10: defaults for replace, override, display ──

    test('defaults: replace=false, override=true, display=defaultLoc', () {
      final entry = LogEntry.fromJson({
        'id': 'e10',
        'timestamp': '2026-02-07T12:00:00Z',
        'session_id': 'sess-1',
        'kind': 'event',
        'severity': 'info',
      });

      expect(entry.replace, isFalse);
      expect(entry.override_, isTrue);
      expect(entry.display, DisplayLocation.defaultLoc);
    });

    // ── Test 11: severity defaults to info when missing ──

    test('severity defaults to info when missing', () {
      final entry = LogEntry.fromJson({
        'id': 'e11',
        'timestamp': '2026-02-07T12:00:00Z',
        'session_id': 'sess-1',
        'kind': 'event',
      });

      expect(entry.severity, Severity.info);
    });

    // ── Test 12: unknown kind defaults to event ──

    test('unknown kind defaults to event', () {
      final entry = LogEntry.fromJson({
        'id': 'e12',
        'timestamp': '2026-02-07T12:00:00Z',
        'session_id': 'sess-1',
        'kind': 'unknown_kind',
        'severity': 'info',
      });

      expect(entry.kind, EntryKind.event);
    });
  });

  group('Enum parsers', () {
    // ── Test 13: parseSeverity ──

    test('parseSeverity returns correct values and defaults to debug', () {
      expect(parseSeverity('debug'), Severity.debug);
      expect(parseSeverity('info'), Severity.info);
      expect(parseSeverity('warning'), Severity.warning);
      expect(parseSeverity('error'), Severity.error);
      expect(parseSeverity('critical'), Severity.critical);
      expect(parseSeverity('unknown'), Severity.debug);
    });

    // ── Test 14: parseEntryKind ──

    test('parseEntryKind returns correct values and defaults to event', () {
      expect(parseEntryKind('session'), EntryKind.session);
      expect(parseEntryKind('event'), EntryKind.event);
      expect(parseEntryKind('data'), EntryKind.data);
      expect(parseEntryKind('bogus'), EntryKind.event);
    });

    // ── Test 15: parseDisplayLocation ──

    test('parseDisplayLocation maps wire strings to enum values', () {
      expect(parseDisplayLocation('default'), DisplayLocation.defaultLoc);
      expect(parseDisplayLocation('static'), DisplayLocation.static_);
      expect(parseDisplayLocation('shelf'), DisplayLocation.shelf);
      expect(parseDisplayLocation('unknown'), DisplayLocation.defaultLoc);
    });

    // ── Test 16: parseSessionAction ──

    test('parseSessionAction returns null for null input', () {
      expect(parseSessionAction(null), isNull);
      expect(parseSessionAction('start'), SessionAction.start);
      expect(parseSessionAction('end'), SessionAction.end);
      expect(parseSessionAction('heartbeat'), SessionAction.heartbeat);
    });
  });

  group('Sub-schema round-trips', () {
    // ── Test 17: ApplicationInfo ──

    test('ApplicationInfo fromJson/toJson round-trip', () {
      final json = {
        'name': 'TestApp',
        'version': '2.0.0',
        'environment': 'staging',
      };
      final info = ApplicationInfo.fromJson(json);
      final output = info.toJson();

      expect(output['name'], 'TestApp');
      expect(output['version'], '2.0.0');
      expect(output['environment'], 'staging');
    });

    // ── Test 18: SourceLocation ──

    test('SourceLocation fromJson/toJson round-trip', () {
      final json = {
        'uri': 'package:app/main.dart',
        'line': 42,
        'column': 10,
        'symbol': 'main',
      };
      final loc = SourceLocation.fromJson(json);
      final output = loc.toJson();

      expect(output['uri'], 'package:app/main.dart');
      expect(output['line'], 42);
      expect(output['column'], 10);
      expect(output['symbol'], 'main');
    });

    // ── Test 19: StackFrame ──

    test('StackFrame fromJson/toJson round-trip', () {
      final json = {
        'location': {'uri': 'app.dart', 'line': 5},
        'isVendor': true,
        'raw': '#0 main (app.dart:5)',
      };
      final frame = StackFrame.fromJson(json);
      final output = frame.toJson();

      expect(output['location']['uri'], 'app.dart');
      expect(output['location']['line'], 5);
      expect(output['isVendor'], isTrue);
      expect(output['raw'], '#0 main (app.dart:5)');
    });

    // ── Test 20: ExceptionData with nested cause ──

    test('ExceptionData fromJson/toJson with nested cause', () {
      final json = {
        'type': 'HttpError',
        'message': '404 Not Found',
        'stackTrace': [
          {
            'location': {'uri': 'http.dart', 'line': 20},
          },
        ],
        'cause': {'message': 'DNS resolution failed'},
      };
      final exc = ExceptionData.fromJson(json);
      final output = exc.toJson();

      expect(output['type'], 'HttpError');
      expect(output['message'], '404 Not Found');
      expect((output['stackTrace'] as List), hasLength(1));
      expect(output['cause']['message'], 'DNS resolution failed');
    });

    // ── Test 21: IconRef ──

    test('IconRef fromJson/toJson round-trip', () {
      final json = {'icon': 'warning', 'color': 'red', 'size': 16.0};
      final icon = IconRef.fromJson(json);
      final output = icon.toJson();

      expect(output['icon'], 'warning');
      expect(output['color'], 'red');
      expect(output['size'], 16.0);
    });

    // ── Test 22: ImageData data variant ──

    test('ImageData fromJson/toJson round-trip (data variant)', () {
      final json = {
        'data': 'base64data==',
        'mime_type': 'image/jpeg',
        'label': 'photo',
        'width': 1920,
        'height': 1080,
      };
      final img = ImageData.fromJson(json);
      final output = img.toJson();

      expect(output['data'], 'base64data==');
      expect(output['mime_type'], 'image/jpeg');
      expect(output['label'], 'photo');
      expect(output['width'], 1920);
      expect(output['height'], 1080);
      expect(output.containsKey('ref'), isFalse);
    });

    // ── Test 23: ImageData ref variant ──

    test('ImageData fromJson/toJson round-trip (ref variant)', () {
      final json = {'ref': 'https://example.com/img.png', 'label': 'banner'};
      final img = ImageData.fromJson(json);
      final output = img.toJson();

      expect(output['ref'], 'https://example.com/img.png');
      expect(output['label'], 'banner');
      expect(output.containsKey('data'), isFalse);
    });

    // ── Test 24: WidgetPayload ──

    test('WidgetPayload fromJson/toJson round-trip', () {
      final json = {
        'type': 'chart',
        'series': [1, 2, 3],
        'title': 'CPU',
      };
      final wp = WidgetPayload.fromJson(json);

      expect(wp.type, 'chart');
      expect(wp.data['series'], [1, 2, 3]);
      expect(wp.data['title'], 'CPU');
      expect(wp.data.containsKey('type'), isFalse);

      final output = wp.toJson();
      expect(output['type'], 'chart');
      expect(output['series'], [1, 2, 3]);
    });

    // ── Test 25: DataState ──

    test('DataState fromJson/toJson round-trip', () {
      final json = {
        'value': 'dark',
        'history': ['light', 'dark'],
        'display': 'shelf',
        'label': 'Theme',
        'icon': {'icon': 'palette'},
        'updated_at': '2026-02-07T12:00:00Z',
      };
      final ds = DataState.fromJson(json);

      expect(ds.value, 'dark');
      expect(ds.history, ['light', 'dark']);
      expect(ds.display, DisplayLocation.shelf);
      expect(ds.label, 'Theme');
      expect(ds.icon, isNotNull);
      expect(ds.icon!.icon, 'palette');
      expect(ds.updatedAt, '2026-02-07T12:00:00Z');

      final output = ds.toJson();
      expect(output['value'], 'dark');
      expect(output['display'], 'shelf');
      expect(output['label'], 'Theme');
    });

    // ── Test 26: DataState with widget ──

    test('DataState with widget payload', () {
      final json = {
        'value': {'cpu': 87.5},
        'display': 'static',
        'widget': {'type': 'gauge', 'max': 100},
      };
      final ds = DataState.fromJson(json);

      expect(ds.display, DisplayLocation.static_);
      expect(ds.widget, isNotNull);
      expect(ds.widget!.type, 'gauge');
      expect(ds.widget!.data['max'], 100);
    });

    // ── Test 27: DataState defaults ──

    test('DataState defaults display to defaultLoc', () {
      final ds = DataState.fromJson({'value': 42});

      expect(ds.display, DisplayLocation.defaultLoc);
      expect(ds.history, isNull);
      expect(ds.widget, isNull);
      expect(ds.label, isNull);
      expect(ds.icon, isNull);
    });
  });
}
