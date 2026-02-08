import 'package:app/plugins/builtin/id_uniquifier_plugin.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late IdUniquifierPlugin plugin;

  setUp(() {
    plugin = IdUniquifierPlugin();
  });

  group('IdUniquifierPlugin identity', () {
    test('has correct id', () {
      expect(plugin.id, 'dev.logger.id-uniquifier');
    });

    test('has correct name', () {
      expect(plugin.name, 'ID Uniquifier');
    });

    test('has correct version', () {
      expect(plugin.version, '1.0.0');
    });

    test('is enabled by default', () {
      expect(plugin.enabled, isTrue);
    });

    test('manifest types contains transform', () {
      expect(plugin.manifest.types, contains('transform'));
    });

    test('displayName is set', () {
      expect(plugin.displayName, isNotEmpty);
    });
  });

  group('idToToken', () {
    test('produces deterministic output', () {
      const id = '550e8400-e29b-41d4-a716-446655440000';
      final token1 = plugin.idToToken(id);
      final token2 = plugin.idToToken(id);
      expect(token1, equals(token2));
    });

    test('returns adjective-animal format', () {
      const id = '550e8400-e29b-41d4-a716-446655440000';
      final token = plugin.idToToken(id);
      expect(token, matches(RegExp(r'^[a-z]+-[a-z]+$')));
    });

    test('different IDs produce different tokens', () {
      final token1 = plugin.idToToken('550e8400-e29b-41d4-a716-446655440000');
      final token2 = plugin.idToToken('660e8400-e29b-41d4-a716-446655440001');
      expect(token1, isNot(equals(token2)));
    });

    test('ObjectID produces valid token', () {
      final token = plugin.idToToken('507f1f77bcf86cd799439011');
      expect(token, matches(RegExp(r'^[a-z]+-[a-z]+$')));
    });
  });

  group('canTransform', () {
    test('detects UUID', () {
      expect(
        plugin.canTransform(
          'User 550e8400-e29b-41d4-a716-446655440000 logged in',
        ),
        isTrue,
      );
    });

    test('detects MongoDB ObjectID', () {
      expect(
        plugin.canTransform('Doc 507f1f77bcf86cd799439011 updated'),
        isTrue,
      );
    });

    test('returns false for plain text (default config)', () {
      // short_id detection is off by default
      expect(plugin.canTransform('Hello world'), isFalse);
    });

    test('respects config — disabled uuid', () {
      plugin.config = const IdUniquifierConfig(
        detectUuids: false,
        detectObjectIds: false,
      );
      expect(
        plugin.canTransform(
          'User 550e8400-e29b-41d4-a716-446655440000 logged in',
        ),
        isFalse,
      );
    });

    test('respects config — enabled short_id', () {
      plugin.config = const IdUniquifierConfig(
        detectUuids: false,
        detectObjectIds: false,
        detectShortIds: true,
      );
      expect(plugin.canTransform('Item ABCDEF1234 created'), isTrue);
    });
  });

  group('transform', () {
    test('annotates UUID with token', () {
      const input = 'User 550e8400-e29b-41d4-a716-446655440000 logged in';
      final result = plugin.transform(input);

      // Original ID should still be present.
      expect(result, contains('550e8400-e29b-41d4-a716-446655440000'));
      // Token should be appended in parentheses.
      expect(result, matches(RegExp(r'550e8400.*\([a-z]+-[a-z]+\)')));
    });

    test('annotates ObjectID with token', () {
      const input = 'Doc 507f1f77bcf86cd799439011 updated';
      final result = plugin.transform(input);

      expect(result, contains('507f1f77bcf86cd799439011'));
      expect(
        result,
        matches(RegExp(r'507f1f77bcf86cd799439011 \([a-z]+-[a-z]+\)')),
      );
    });

    test('handles multiple IDs in one string', () {
      const input =
          'Linked 550e8400-e29b-41d4-a716-446655440000 '
          'to 660e8400-e29b-41d4-a716-446655440001';
      final result = plugin.transform(input);

      // Both should be annotated.
      final tokenPattern = RegExp(r'\([a-z]+-[a-z]+\)');
      expect(tokenPattern.allMatches(result).length, 2);
    });

    test('returns unchanged text when no IDs found', () {
      const input = 'Simple log message with no IDs';
      expect(plugin.transform(input), equals(input));
    });

    test('same ID always gets the same token', () {
      const id = '550e8400-e29b-41d4-a716-446655440000';
      final result1 = plugin.transform('First $id here');
      final result2 = plugin.transform('Second $id there');

      final tokenPattern = RegExp(r'\(([a-z]+-[a-z]+)\)');
      final token1 = tokenPattern.firstMatch(result1)?.group(1);
      final token2 = tokenPattern.firstMatch(result2)?.group(1);
      expect(token1, equals(token2));
    });
  });

  group('IdUniquifierConfig', () {
    test('defaults enable uuid and objectid, disable short_id', () {
      const config = IdUniquifierConfig();
      expect(config.detectUuids, isTrue);
      expect(config.detectObjectIds, isTrue);
      expect(config.detectShortIds, isFalse);
    });

    test('copyWith creates modified copy', () {
      const config = IdUniquifierConfig();
      final modified = config.copyWith(detectShortIds: true);
      expect(modified.detectShortIds, isTrue);
      expect(modified.detectUuids, isTrue); // unchanged
    });
  });
}
