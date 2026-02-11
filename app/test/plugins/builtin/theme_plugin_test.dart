import 'package:app/plugins/builtin/theme_plugin.dart';
import 'package:app/plugins/plugin_types.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ThemePlugin plugin;

  setUp(() {
    plugin = ThemePlugin();
  });

  group('ThemePlugin identity', () {
    test('has correct id', () {
      expect(plugin.id, 'dev.logger.theme');
    });

    test('has correct name', () {
      expect(plugin.name, 'Theme');
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

    test('types contains tool', () {
      expect(plugin.manifest.types, contains('tool'));
    });

    test('group is tools', () {
      expect(plugin.manifest.group, ToolGroups.tools);
    });

    test('has config panel', () {
      expect(plugin.manifest.hasConfigPanel, isTrue);
    });

    test('is not disableable', () {
      expect(plugin.manifest.disableable, isFalse);
    });
  });

  group('tool properties', () {
    test('toolLabel is Theme', () {
      expect(plugin.toolLabel, 'Theme');
    });

    test('toolIcon is palette_outlined', () {
      expect(plugin.toolIcon, Icons.palette_outlined);
    });
  });

  group('buildToolPanel', () {
    testWidgets('renders color scheme heading', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => plugin.buildToolPanel(context),
            ),
          ),
        ),
      );
      expect(find.text('Color Scheme'), findsOneWidget);
      expect(find.text('Ayu Dark'), findsOneWidget);
    });
  });
}
