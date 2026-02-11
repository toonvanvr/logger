import 'package:app/models/log_enums.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Severity', () {
    test('has exactly 5 values', () {
      expect(Severity.values, hasLength(5));
    });

    test('contains expected values', () {
      expect(Severity.values, containsAll([
        Severity.debug,
        Severity.info,
        Severity.warning,
        Severity.error,
        Severity.critical,
      ]));
    });
  });

  group('EntryKind', () {
    test('has exactly 3 values', () {
      expect(EntryKind.values, hasLength(3));
    });

    test('contains expected values', () {
      expect(EntryKind.values, containsAll([
        EntryKind.session,
        EntryKind.event,
        EntryKind.data,
      ]));
    });
  });

  group('DisplayLocation', () {
    test('has exactly 3 values', () {
      expect(DisplayLocation.values, hasLength(3));
    });
  });

  group('SessionAction', () {
    test('has exactly 3 values', () {
      expect(SessionAction.values, hasLength(3));
    });
  });

  group('parseSeverity', () {
    test('parses known values', () {
      expect(parseSeverity('debug'), Severity.debug);
      expect(parseSeverity('info'), Severity.info);
      expect(parseSeverity('warning'), Severity.warning);
      expect(parseSeverity('error'), Severity.error);
      expect(parseSeverity('critical'), Severity.critical);
    });

    test('defaults to debug for unknown', () {
      expect(parseSeverity('unknown'), Severity.debug);
      expect(parseSeverity(''), Severity.debug);
    });
  });

  group('parseEntryKind', () {
    test('parses known values', () {
      expect(parseEntryKind('session'), EntryKind.session);
      expect(parseEntryKind('event'), EntryKind.event);
      expect(parseEntryKind('data'), EntryKind.data);
    });

    test('defaults to event for unknown', () {
      expect(parseEntryKind('unknown'), EntryKind.event);
    });
  });

  group('parseDisplayLocation', () {
    test('parses known values', () {
      expect(parseDisplayLocation('default'), DisplayLocation.defaultLoc);
      expect(parseDisplayLocation('static'), DisplayLocation.static_);
      expect(parseDisplayLocation('shelf'), DisplayLocation.shelf);
    });

    test('defaults to defaultLoc for unknown', () {
      expect(parseDisplayLocation('unknown'), DisplayLocation.defaultLoc);
    });
  });

  group('parseSessionAction', () {
    test('returns null for null input', () {
      expect(parseSessionAction(null), isNull);
    });

    test('parses known values', () {
      expect(parseSessionAction('start'), SessionAction.start);
      expect(parseSessionAction('end'), SessionAction.end);
      expect(parseSessionAction('heartbeat'), SessionAction.heartbeat);
    });

    test('defaults to start for unknown', () {
      expect(parseSessionAction('unknown'), SessionAction.start);
    });
  });
}
