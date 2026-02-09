import 'package:app/models/log_entry.dart';
import 'package:app/plugins/builtin/kv_plugin.dart';
import 'package:app/plugins/builtin/progress_plugin.dart';
import 'package:app/plugins/builtin/table_plugin.dart';
import 'package:app/plugins/plugin_manifest.dart';
import 'package:app/plugins/plugin_registry.dart';
import 'package:app/plugins/plugin_types.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ─── Helpers ─────────────────────────────────────────────────────────

class _StubRendererPlugin extends RendererPlugin with EnableablePlugin {
  @override
  final String id;
  @override
  final String name;
  @override
  String get version => '0.1.0';
  @override
  String get description => 'stub';

  @override
  PluginManifest get manifest =>
      PluginManifest(id: id, name: name, version: version, types: ['renderer']);

  @override
  final Set<String> customTypes;

  _StubRendererPlugin({
    required this.id,
    this.name = 'Stub', // ignore: unused_element_parameter
    required this.customTypes,
  });

  @override
  Widget buildRenderer(
    BuildContext context,
    Map<String, dynamic> data,
    LogEntry entry,
  ) {
    return Text('stub:${entry.widget?.type}');
  }

  @override
  void onRegister(PluginRegistry registry) {}
  @override
  void onDispose() {}
}

class _StubFilterPlugin extends FilterPlugin with EnableablePlugin {
  @override
  final String id;
  @override
  String get name => 'Stub Filter';
  @override
  String get version => '0.1.0';
  @override
  String get description => 'stub filter';

  @override
  PluginManifest get manifest =>
      PluginManifest(id: id, name: name, version: version, types: ['filter']);

  @override
  String get filterLabel => 'Stub';
  @override
  IconData get filterIcon => Icons.filter_alt;

  _StubFilterPlugin({required this.id});

  @override
  bool matches(LogEntry entry, String query) => true;
  @override
  List<String> getSuggestions(String partial, List<LogEntry> entries) => [];
  @override
  void onRegister(PluginRegistry registry) {}
  @override
  void onDispose() {}
}

// ─── Tests ───────────────────────────────────────────────────────────

void main() {
  late PluginRegistry registry;

  setUp(() {
    // Reset singleton state between tests
    PluginRegistry.instance.disposeAll();
    registry = PluginRegistry.instance;
  });

  tearDown(() {
    PluginRegistry.instance.disposeAll();
  });

  group('PluginRegistry', () {
    test('register and retrieve a renderer plugin', () {
      final plugin = _StubRendererPlugin(
        id: 'test.renderer',
        customTypes: {'chart'},
      );

      registry.register(plugin);

      expect(registry.length, 1);
      expect(registry.resolveRenderer('chart'), same(plugin));
    });

    test('resolveRenderer returns null for unknown type', () {
      expect(registry.resolveRenderer('nonexistent'), isNull);
    });

    test('rejects duplicate plugin ids', () {
      final p1 = _StubRendererPlugin(id: 'dup.id', customTypes: {'a'});
      final p2 = _StubRendererPlugin(id: 'dup.id', customTypes: {'b'});

      registry.register(p1);
      expect(
        () => registry.register(p2),
        throwsA(isA<PluginConflictException>()),
      );
    });

    test('unregister removes plugin and renderer index', () {
      final plugin = _StubRendererPlugin(
        id: 'test.remove',
        customTypes: {'removable'},
      );

      registry.register(plugin);
      expect(registry.resolveRenderer('removable'), isNotNull);

      registry.unregister('test.remove');
      expect(registry.resolveRenderer('removable'), isNull);
      expect(registry.length, 0);
    });

    test('getPlugins returns typed list', () {
      final renderer = _StubRendererPlugin(id: 'test.r', customTypes: {'x'});
      final filter = _StubFilterPlugin(id: 'test.f');

      registry.register(renderer);
      registry.register(filter);

      expect(registry.getPlugins<RendererPlugin>(), [renderer]);
      expect(registry.getPlugins<FilterPlugin>(), [filter]);
      expect(registry.getPlugins<LoggerPlugin>(), hasLength(2));
    });

    test('setEnabled disables and re-enables renderer resolution', () {
      final plugin = _StubRendererPlugin(
        id: 'test.toggle',
        customTypes: {'toggled'},
      );

      registry.register(plugin);
      expect(registry.resolveRenderer('toggled'), isNotNull);

      registry.setEnabled('test.toggle', false);
      expect(registry.resolveRenderer('toggled'), isNull);

      registry.setEnabled('test.toggle', true);
      expect(registry.resolveRenderer('toggled'), isNotNull);
    });

    test('getEnabledPlugins filters disabled plugins', () {
      final p1 = _StubRendererPlugin(id: 'en.a', customTypes: {'a'});
      final p2 = _StubRendererPlugin(id: 'en.b', customTypes: {'b'});

      registry.register(p1);
      registry.register(p2);
      registry.setEnabled('en.b', false);

      expect(registry.getEnabledPlugins<RendererPlugin>(), [p1]);
    });

    test('manifests returns all manifests', () {
      registry.register(_StubRendererPlugin(id: 'man.a', customTypes: {'a'}));
      registry.register(_StubFilterPlugin(id: 'man.b'));

      final manifests = registry.manifests;
      expect(manifests, hasLength(2));
      expect(manifests.map((m) => m.id), containsAll(['man.a', 'man.b']));
    });

    test('disposeAll clears all state', () {
      registry.register(_StubRendererPlugin(id: 'disp.a', customTypes: {'a'}));
      registry.register(_StubFilterPlugin(id: 'disp.b'));

      registry.disposeAll();
      expect(registry.length, 0);
      expect(registry.resolveRenderer('a'), isNull);
      expect(registry.manifests, isEmpty);
    });

    test('getPlugin returns plugin by id', () {
      final plugin = _StubRendererPlugin(id: 'get.me', customTypes: {'x'});
      registry.register(plugin);

      expect(registry.getPlugin('get.me'), same(plugin));
      expect(registry.getPlugin('nonexistent'), isNull);
    });
  });

  group('Built-in plugins', () {
    test('ProgressRendererPlugin handles progress type', () {
      final plugin = ProgressRendererPlugin();
      expect(plugin.id, 'dev.logger.progress-renderer');
      expect(plugin.customTypes, {'progress'});
      expect(plugin.enabled, isTrue);
    });

    test('TableRendererPlugin handles table type', () {
      final plugin = TableRendererPlugin();
      expect(plugin.id, 'dev.logger.table-renderer');
      expect(plugin.customTypes, {'table'});
      expect(plugin.enabled, isTrue);
    });

    test('KvRendererPlugin handles kv type', () {
      final plugin = KvRendererPlugin();
      expect(plugin.id, 'dev.logger.kv-renderer');
      expect(plugin.customTypes, {'kv'});
      expect(plugin.enabled, isTrue);
    });

    test('all built-in plugins register without conflict', () {
      registry.register(ProgressRendererPlugin());
      registry.register(TableRendererPlugin());
      registry.register(KvRendererPlugin());

      expect(registry.length, 3);
      expect(
        registry.resolveRenderer('progress'),
        isA<ProgressRendererPlugin>(),
      );
      expect(registry.resolveRenderer('table'), isA<TableRendererPlugin>());
      expect(registry.resolveRenderer('kv'), isA<KvRendererPlugin>());
    });
  });

  group('PluginManifest', () {
    test('toString includes id and version', () {
      const manifest = PluginManifest(
        id: 'test.plugin',
        name: 'Test',
        version: '1.2.3',
        types: ['renderer'],
      );
      expect(manifest.toString(), contains('test.plugin'));
      expect(manifest.toString(), contains('1.2.3'));
    });

    test('defaults tier to stdlib', () {
      const manifest = PluginManifest(
        id: 'x',
        name: 'X',
        version: '0.0.1',
        types: [],
      );
      expect(manifest.tier, PluginTier.stdlib);
    });
  });
}
