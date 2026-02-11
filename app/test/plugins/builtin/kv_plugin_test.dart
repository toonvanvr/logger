import 'package:app/plugins/builtin/kv_plugin.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late KvRendererPlugin plugin;

  setUp(() {
    plugin = KvRendererPlugin();
  });

  group('KvRendererPlugin identity', () {
    test('has correct id', () {
      expect(plugin.id, 'dev.logger.kv-renderer');
    });

    test('has correct name', () {
      expect(plugin.name, 'Key-Value Renderer');
    });

    test('has correct version', () {
      expect(plugin.version, '1.0.0');
    });

    test('has description', () {
      expect(plugin.description, isNotEmpty);
    });

    test('is enabled by default', () {
      expect(plugin.enabled, isTrue);
    });
  });

  group('manifest', () {
    test('id matches plugin id', () {
      expect(plugin.manifest.id, plugin.id);
    });

    test('types contains renderer', () {
      expect(plugin.manifest.types, contains('renderer'));
    });

    test('is stdlib tier', () {
      expect(plugin.manifest.tier.name, 'stdlib');
    });
  });

  group('customTypes', () {
    test('handles kv type', () {
      expect(plugin.customTypes, contains('kv'));
    });

    test('only handles kv', () {
      expect(plugin.customTypes, hasLength(1));
    });
  });

  group('enableable', () {
    test('can be disabled', () {
      plugin.setEnabled(false);
      expect(plugin.enabled, isFalse);
    });

    test('can be re-enabled', () {
      plugin.setEnabled(false);
      plugin.setEnabled(true);
      expect(plugin.enabled, isTrue);
    });
  });

  group('buildPreview', () {
    test('returns null by default', () {
      expect(plugin.buildPreview(const {}), isNull);
    });
  });
}
