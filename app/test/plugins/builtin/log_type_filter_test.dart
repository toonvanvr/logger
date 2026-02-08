import 'package:app/models/log_entry.dart';
import 'package:app/plugins/builtin/log_type_filter_plugin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ─── Helpers ─────────────────────────────────────────────────────────

LogEntry _entry({required LogType type}) => LogEntry(
  id: 'e1',
  timestamp: '2026-01-01T00:00:00Z',
  sessionId: 's1',
  severity: Severity.info,
  type: type,
  text: 'test',
);

void main() {
  late LogTypeFilterPlugin plugin;

  setUp(() {
    plugin = LogTypeFilterPlugin();
  });

  group('LogTypeFilterPlugin identity', () {
    test('has correct id', () {
      expect(plugin.id, 'dev.logger.log-type-filter');
    });

    test('has correct name', () {
      expect(plugin.name, 'Log Type Filter');
    });

    test('has correct version', () {
      expect(plugin.version, '1.0.0');
    });

    test('is enabled by default', () {
      expect(plugin.enabled, isTrue);
    });

    test('manifest types contains filter', () {
      expect(plugin.manifest.types, contains('filter'));
    });

    test('filterLabel is Type', () {
      expect(plugin.filterLabel, 'Type');
    });

    test('filterIcon is category', () {
      expect(plugin.filterIcon, Icons.category);
    });
  });

  group('matches', () {
    test('returns true for any entry when no active types', () {
      expect(plugin.matches(_entry(type: LogType.text), ''), isTrue);
      expect(plugin.matches(_entry(type: LogType.json), ''), isTrue);
      expect(plugin.matches(_entry(type: LogType.html), ''), isTrue);
    });

    test('returns true when entry type is in active set', () {
      plugin.setActiveTypes({'text', 'json'});
      expect(plugin.matches(_entry(type: LogType.text), ''), isTrue);
      expect(plugin.matches(_entry(type: LogType.json), ''), isTrue);
    });

    test('returns false when entry type is not in active set', () {
      plugin.setActiveTypes({'text'});
      expect(plugin.matches(_entry(type: LogType.json), ''), isFalse);
      expect(plugin.matches(_entry(type: LogType.html), ''), isFalse);
    });
  });

  group('activeTypes management', () {
    test('starts empty', () {
      expect(plugin.activeTypes, isEmpty);
    });

    test('setActiveTypes replaces existing', () {
      plugin.setActiveTypes({'text'});
      plugin.setActiveTypes({'json', 'html'});
      expect(plugin.activeTypes, {'json', 'html'});
    });

    test('toggleType adds and removes', () {
      plugin.toggleType('text');
      expect(plugin.activeTypes, {'text'});

      plugin.toggleType('json');
      expect(plugin.activeTypes, {'text', 'json'});

      plugin.toggleType('text');
      expect(plugin.activeTypes, {'json'});
    });

    test('clearTypes empties the set', () {
      plugin.setActiveTypes({'text', 'json'});
      plugin.clearTypes();
      expect(plugin.activeTypes, isEmpty);
    });

    test('activeTypes returns unmodifiable view', () {
      plugin.setActiveTypes({'text'});
      expect(() => plugin.activeTypes.add('json'), throwsUnsupportedError);
    });
  });

  group('getSuggestions', () {
    final entries = [
      _entry(type: LogType.text),
      _entry(type: LogType.json),
      _entry(type: LogType.text),
      _entry(type: LogType.html),
    ];

    test('returns sorted unique types from entries', () {
      final suggestions = plugin.getSuggestions('', entries);
      expect(suggestions, ['html', 'json', 'text']);
    });

    test('filters by partial query', () {
      final suggestions = plugin.getSuggestions('js', entries);
      expect(suggestions, ['json']);
    });

    test('is case-insensitive', () {
      final suggestions = plugin.getSuggestions('TE', entries);
      expect(suggestions, ['text']);
    });

    test('returns empty when no match', () {
      final suggestions = plugin.getSuggestions('xyz', entries);
      expect(suggestions, isEmpty);
    });

    test('returns empty for empty entries', () {
      final suggestions = plugin.getSuggestions('', []);
      expect(suggestions, isEmpty);
    });
  });

  group('lifecycle', () {
    test('onDispose clears active types', () {
      plugin.setActiveTypes({'text', 'json'});
      plugin.onDispose();
      expect(plugin.activeTypes, isEmpty);
    });
  });
}
