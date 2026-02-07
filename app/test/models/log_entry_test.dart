import 'package:app/models/log_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LogEntry.fromJson', () {
    // ── Test 1: required fields ──

    test('parses required fields', () {
      final entry = LogEntry.fromJson({
        'id': 'e1',
        'timestamp': '2026-02-07T12:00:00Z',
        'session_id': 'sess-1',
        'severity': 'warning',
        'type': 'text',
      });

      expect(entry.id, 'e1');
      expect(entry.timestamp, '2026-02-07T12:00:00Z');
      expect(entry.sessionId, 'sess-1');
      expect(entry.severity, Severity.warning);
      expect(entry.type, LogType.text);
    });

    // ── Test 2: optional text/json/html/binary fields ──

    test('parses all optional content fields', () {
      final entry = LogEntry.fromJson({
        'id': 'e2',
        'timestamp': '2026-02-07T12:00:00Z',
        'session_id': 'sess-1',
        'severity': 'info',
        'type': 'text',
        'text': 'hello',
        'html': '<b>bold</b>',
        'binary': 'AQID',
        'json': {'key': 'value'},
      });

      expect(entry.text, 'hello');
      expect(entry.html, '<b>bold</b>');
      expect(entry.binary, 'AQID');
      expect(entry.jsonData, {'key': 'value'});
    });

    // ── Test 3: nested ApplicationInfo ──

    test('parses nested ApplicationInfo', () {
      final entry = LogEntry.fromJson({
        'id': 'e3',
        'timestamp': '2026-02-07T12:00:00Z',
        'session_id': 'sess-1',
        'severity': 'info',
        'type': 'session',
        'application': {
          'name': 'MyApp',
          'version': '1.2.3',
          'environment': 'production',
        },
      });

      expect(entry.application, isNotNull);
      expect(entry.application!.name, 'MyApp');
      expect(entry.application!.version, '1.2.3');
      expect(entry.application!.environment, 'production');
    });

    // ── Test 4: nested ExceptionData with cause chain ──

    test('parses nested ExceptionData with cause chain', () {
      final entry = LogEntry.fromJson({
        'id': 'e4',
        'timestamp': '2026-02-07T12:00:00Z',
        'session_id': 'sess-1',
        'severity': 'error',
        'type': 'text',
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

    // ── Test 5: nested ImageData ──

    test('parses nested ImageData', () {
      final entry = LogEntry.fromJson({
        'id': 'e5',
        'timestamp': '2026-02-07T12:00:00Z',
        'session_id': 'sess-1',
        'severity': 'info',
        'type': 'image',
        'image': {
          'data': 'iVBORw0KGgo=',
          'mimeType': 'image/png',
          'label': 'screenshot',
          'width': 800,
          'height': 600,
        },
      });

      expect(entry.image, isNotNull);
      expect(entry.image!.data, 'iVBORw0KGgo=');
      expect(entry.image!.mimeType, 'image/png');
      expect(entry.image!.label, 'screenshot');
      expect(entry.image!.width, 800);
      expect(entry.image!.height, 600);
    });

    // ── Test 6: nested IconRef ──

    test('parses nested IconRef', () {
      final entry = LogEntry.fromJson({
        'id': 'e6',
        'timestamp': '2026-02-07T12:00:00Z',
        'session_id': 'sess-1',
        'severity': 'info',
        'type': 'text',
        'icon': {'icon': 'star', 'color': '#FFD700', 'size': 24.0},
      });

      expect(entry.icon, isNotNull);
      expect(entry.icon!.icon, 'star');
      expect(entry.icon!.color, '#FFD700');
      expect(entry.icon!.size, 24.0);
    });

    // ── Test 7: maps 'json' key to jsonData ──

    test('maps json key to jsonData field', () {
      final entry = LogEntry.fromJson({
        'id': 'e7',
        'timestamp': '2026-02-07T12:00:00Z',
        'session_id': 'sess-1',
        'severity': 'info',
        'type': 'json',
        'json': [1, 2, 3],
      });

      expect(entry.jsonData, [1, 2, 3]);
    });

    // ── Test 8: group fields ──

    test('parses group fields', () {
      final entry = LogEntry.fromJson({
        'id': 'e8',
        'timestamp': '2026-02-07T12:00:00Z',
        'session_id': 'sess-1',
        'severity': 'info',
        'type': 'group',
        'group_id': 'g1',
        'group_action': 'open',
        'group_label': 'Network Requests',
        'group_collapsed': true,
      });

      expect(entry.groupId, 'g1');
      expect(entry.groupAction, GroupAction.open);
      expect(entry.groupLabel, 'Network Requests');
      expect(entry.groupCollapsed, isTrue);
    });

    // ── Test 9: state fields ──

    test('parses state fields', () {
      final entry = LogEntry.fromJson({
        'id': 'e9',
        'timestamp': '2026-02-07T12:00:00Z',
        'session_id': 'sess-1',
        'severity': 'info',
        'type': 'state',
        'state_key': 'theme',
        'state_value': 'dark',
      });

      expect(entry.stateKey, 'theme');
      expect(entry.stateValue, 'dark');
    });

    // ── Test 10: RPC fields ──

    test('parses RPC fields', () {
      final entry = LogEntry.fromJson({
        'id': 'e10',
        'timestamp': '2026-02-07T12:00:00Z',
        'session_id': 'sess-1',
        'severity': 'info',
        'type': 'rpc',
        'rpc_id': 'rpc-1',
        'rpc_direction': 'request',
        'rpc_method': 'getState',
        'rpc_args': {'key': 'theme'},
        'rpc_response': {'value': 'dark'},
        'rpc_error': null,
      });

      expect(entry.rpcId, 'rpc-1');
      expect(entry.rpcDirection, RpcDirection.request);
      expect(entry.rpcMethod, 'getState');
      expect(entry.rpcArgs, {'key': 'theme'});
      expect(entry.rpcResponse, {'value': 'dark'});
      expect(entry.rpcError, isNull);
    });

    // ── Test 11: tags ──

    test('parses tags as Map<String, String>', () {
      final entry = LogEntry.fromJson({
        'id': 'e11',
        'timestamp': '2026-02-07T12:00:00Z',
        'session_id': 'sess-1',
        'severity': 'info',
        'type': 'text',
        'tags': {'env': 'prod', 'region': 'eu-west'},
      });

      expect(entry.tags, {'env': 'prod', 'region': 'eu-west'});
    });

    // ── Test 12: replace, custom_type, custom_data ──

    test('parses replace, custom_type, custom_data', () {
      final entry = LogEntry.fromJson({
        'id': 'e12',
        'timestamp': '2026-02-07T12:00:00Z',
        'session_id': 'sess-1',
        'severity': 'info',
        'type': 'custom',
        'replace': true,
        'custom_type': 'metric',
        'custom_data': {'cpu': 87.5},
      });

      expect(entry.replace, isTrue);
      expect(entry.customType, 'metric');
      expect(entry.customData, {'cpu': 87.5});
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

    // ── Test 14: parseLogType ──

    test('parseLogType returns correct values and defaults to text', () {
      expect(parseLogType('text'), LogType.text);
      expect(parseLogType('json'), LogType.json);
      expect(parseLogType('html'), LogType.html);
      expect(parseLogType('binary'), LogType.binary);
      expect(parseLogType('image'), LogType.image);
      expect(parseLogType('state'), LogType.state);
      expect(parseLogType('group'), LogType.group);
      expect(parseLogType('rpc'), LogType.rpc);
      expect(parseLogType('session'), LogType.session);
      expect(parseLogType('custom'), LogType.custom);
      expect(parseLogType('bogus'), LogType.text);
    });

    // ── Test 15: parseGroupAction ──

    test('parseGroupAction returns null for null input', () {
      expect(parseGroupAction(null), isNull);
      expect(parseGroupAction('open'), GroupAction.open);
      expect(parseGroupAction('close'), GroupAction.close);
    });

    // ── Test 16: parseSessionAction ──

    test('parseSessionAction returns null for null input', () {
      expect(parseSessionAction(null), isNull);
      expect(parseSessionAction('start'), SessionAction.start);
      expect(parseSessionAction('end'), SessionAction.end);
      expect(parseSessionAction('heartbeat'), SessionAction.heartbeat);
    });

    // ── Test 17: parseRpcDirection ──

    test('parseRpcDirection returns null for null input', () {
      expect(parseRpcDirection(null), isNull);
      expect(parseRpcDirection('request'), RpcDirection.request);
      expect(parseRpcDirection('response'), RpcDirection.response);
      expect(parseRpcDirection('error'), RpcDirection.error);
    });
  });

  group('Sub-schema round-trips', () {
    // ── Test 18: ApplicationInfo ──

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

    // ── Test 19: SourceLocation ──

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

    // ── Test 20: StackFrame ──

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

    // ── Test 21: ExceptionData with nested cause ──

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

    // ── Test 22: IconRef ──

    test('IconRef fromJson/toJson round-trip', () {
      final json = {'icon': 'warning', 'color': 'red', 'size': 16.0};
      final icon = IconRef.fromJson(json);
      final output = icon.toJson();

      expect(output['icon'], 'warning');
      expect(output['color'], 'red');
      expect(output['size'], 16.0);
    });

    // ── Test 23: ImageData data variant ──

    test('ImageData fromJson/toJson round-trip (data variant)', () {
      final json = {
        'data': 'base64data==',
        'mimeType': 'image/jpeg',
        'label': 'photo',
        'width': 1920,
        'height': 1080,
      };
      final img = ImageData.fromJson(json);
      final output = img.toJson();

      expect(output['data'], 'base64data==');
      expect(output['mimeType'], 'image/jpeg');
      expect(output['label'], 'photo');
      expect(output['width'], 1920);
      expect(output['height'], 1080);
      expect(output.containsKey('ref'), isFalse);
    });

    // ── Test 24: ImageData ref variant ──

    test('ImageData fromJson/toJson round-trip (ref variant)', () {
      final json = {'ref': 'https://example.com/img.png', 'label': 'banner'};
      final img = ImageData.fromJson(json);
      final output = img.toJson();

      expect(output['ref'], 'https://example.com/img.png');
      expect(output['label'], 'banner');
      expect(output.containsKey('data'), isFalse);
    });
  });
}
