import 'package:app/models/log_entry.dart';
import 'package:app/plugins/builtin/smart_search_plugin.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers.dart';

LogEntry _makeEntry({String text = ''}) {
  return makeTestEntry(text: text);
}

void main() {
  late SmartSearchPlugin plugin;

  setUp(() {
    plugin = SmartSearchPlugin();
  });

  group('UUID matching', () {
    const fullUuid = '550e8400-e29b-41d4-a716-446655440000';
    const partialUuid = '550e8400-e29b';

    test('matches full UUID with uuid: prefix', () {
      final entry = _makeEntry(text: 'request id $fullUuid done');
      expect(plugin.matches(entry, 'uuid:$fullUuid'), isTrue);
    });

    test('does not match partial UUID (only first two segments)', () {
      final entry = _makeEntry(text: 'id is $partialUuid only');
      expect(plugin.matches(entry, 'uuid:$partialUuid'), isFalse);
    });

    test('matches partial search within full UUID', () {
      final entry = _makeEntry(text: 'id $fullUuid');
      expect(plugin.matches(entry, 'uuid:550e8400'), isTrue);
    });
  });

  group('UUID suggestion extraction', () {
    const uuid1 = '550e8400-e29b-41d4-a716-446655440000';
    const uuid2 = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';

    test('extracts full UUIDs from entries', () {
      final entries = [
        _makeEntry(text: 'req $uuid1 started'),
        _makeEntry(text: 'req $uuid2 started'),
      ];

      final suggestions = plugin.getSuggestions('uuid:', entries);

      expect(suggestions, contains('uuid:$uuid1'));
      expect(suggestions, contains('uuid:$uuid2'));
    });

    test('does not extract partial UUID segments', () {
      // Text with only 2 UUID segments — should NOT match.
      final entries = [_makeEntry(text: 'partial 550e8400-e29b only')];

      final suggestions = plugin.getSuggestions('uuid:', entries);
      expect(suggestions, isEmpty);
    });

    test('filters suggestions by partial value', () {
      final entries = [
        _makeEntry(text: 'req $uuid1'),
        _makeEntry(text: 'req $uuid2'),
      ];

      final suggestions = plugin.getSuggestions('uuid:a1b2', entries);

      expect(suggestions, contains('uuid:$uuid2'));
      expect(suggestions, isNot(contains('uuid:$uuid1')));
    });
  });
}
