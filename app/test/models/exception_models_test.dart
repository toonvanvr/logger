import 'package:app/models/exception_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SourceLocation', () {
    test('constructor sets required and optional fields', () {
      const loc = SourceLocation(
        uri: 'app.dart',
        line: 10,
        column: 5,
        symbol: 'main',
      );
      expect(loc.uri, 'app.dart');
      expect(loc.line, 10);
      expect(loc.column, 5);
      expect(loc.symbol, 'main');
    });

    test('fromJson parses all fields', () {
      final loc = SourceLocation.fromJson({
        'uri': 'lib/main.dart',
        'line': 42,
        'column': 8,
        'symbol': 'build',
      });
      expect(loc.uri, 'lib/main.dart');
      expect(loc.line, 42);
      expect(loc.column, 8);
      expect(loc.symbol, 'build');
    });

    test('fromJson handles missing optional fields', () {
      final loc = SourceLocation.fromJson({'uri': 'test.dart'});
      expect(loc.uri, 'test.dart');
      expect(loc.line, isNull);
      expect(loc.column, isNull);
      expect(loc.symbol, isNull);
    });

    test('toJson omits null fields', () {
      const loc = SourceLocation(uri: 'a.dart');
      final json = loc.toJson();
      expect(json['uri'], 'a.dart');
      expect(json.containsKey('line'), isFalse);
      expect(json.containsKey('column'), isFalse);
      expect(json.containsKey('symbol'), isFalse);
    });
  });

  group('StackFrame', () {
    test('constructor with required location', () {
      const frame = StackFrame(
        location: SourceLocation(uri: 'app.dart', line: 1),
      );
      expect(frame.location.uri, 'app.dart');
      expect(frame.isVendor, isNull);
      expect(frame.raw, isNull);
    });

    test('fromJson parses all fields', () {
      final frame = StackFrame.fromJson({
        'location': {'uri': 'pkg/lib.dart', 'line': 5},
        'is_vendor': true,
        'raw': 'at pkg/lib.dart:5',
      });
      expect(frame.location.uri, 'pkg/lib.dart');
      expect(frame.location.line, 5);
      expect(frame.isVendor, isTrue);
      expect(frame.raw, 'at pkg/lib.dart:5');
    });

    test('toJson round-trips', () {
      final frame = StackFrame.fromJson({
        'location': {'uri': 'x.dart', 'line': 1},
        'is_vendor': false,
        'raw': 'raw line',
      });
      final json = frame.toJson();
      expect(json['location']['uri'], 'x.dart');
      expect(json['is_vendor'], isFalse);
      expect(json['raw'], 'raw line');
    });

    test('toJson omits null optional fields', () {
      const frame = StackFrame(
        location: SourceLocation(uri: 'a.dart'),
      );
      final json = frame.toJson();
      expect(json.containsKey('is_vendor'), isFalse);
      expect(json.containsKey('raw'), isFalse);
    });
  });

  group('ExceptionData', () {
    test('constructor with required message', () {
      const ex = ExceptionData(message: 'something broke');
      expect(ex.message, 'something broke');
      expect(ex.type, isNull);
      expect(ex.handled, isTrue);
      expect(ex.inner, isNull);
    });

    test('fromJson parses full exception', () {
      final ex = ExceptionData.fromJson({
        'type': 'TypeError',
        'message': 'null ref',
        'stack_trace': 'at main.dart:10',
        'source': 'main.dart',
        'handled': false,
      });
      expect(ex.type, 'TypeError');
      expect(ex.message, 'null ref');
      expect(ex.stackTrace, 'at main.dart:10');
      expect(ex.source, 'main.dart');
      expect(ex.handled, isFalse);
    });

    test('fromJson parses nested inner exception', () {
      final ex = ExceptionData.fromJson({
        'message': 'outer',
        'inner': {
          'message': 'inner',
          'type': 'RangeError',
        },
      });
      expect(ex.message, 'outer');
      expect(ex.inner, isNotNull);
      expect(ex.inner!.message, 'inner');
      expect(ex.inner!.type, 'RangeError');
    });

    test('fromJson defaults handled to true', () {
      final ex = ExceptionData.fromJson({'message': 'err'});
      expect(ex.handled, isTrue);
    });

    test('toJson omits null fields', () {
      const ex = ExceptionData(message: 'fail');
      final json = ex.toJson();
      expect(json['message'], 'fail');
      expect(json['handled'], isTrue);
      expect(json.containsKey('type'), isFalse);
      expect(json.containsKey('stack_trace'), isFalse);
      expect(json.containsKey('inner'), isFalse);
      expect(json.containsKey('source'), isFalse);
    });

    test('toJson round-trips nested exception', () {
      const ex = ExceptionData(
        type: 'AppError',
        message: 'outer',
        inner: ExceptionData(message: 'cause'),
      );
      final json = ex.toJson();
      expect(json['inner']['message'], 'cause');
    });
  });
}
