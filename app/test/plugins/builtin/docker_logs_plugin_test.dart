import 'package:app/plugins/builtin/docker_logs_plugin.dart';
import 'package:app/plugins/plugin_types.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DockerLogsPlugin plugin;

  setUp(() {
    plugin = DockerLogsPlugin();
  });

  group('DockerLogsPlugin identity', () {
    test('has correct id', () {
      expect(plugin.id, 'dev.logger.docker-logs');
    });

    test('has correct name', () {
      expect(plugin.name, 'Docker Container Logs');
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

    test('group is connections', () {
      expect(plugin.manifest.group, ToolGroups.connections);
    });

    test('has config panel', () {
      expect(plugin.manifest.hasConfigPanel, isTrue);
    });

    test('is disableable', () {
      expect(plugin.manifest.disableable, isTrue);
    });
  });

  group('tool properties', () {
    test('toolLabel is Docker Logs', () {
      expect(plugin.toolLabel, 'Docker Logs');
    });

    test('toolIcon is directions_boat', () {
      expect(plugin.toolIcon, Icons.directions_boat);
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

  group('statusBarItems', () {
    test('returns item when enabled', () {
      expect(plugin.statusBarItems, hasLength(1));
      expect(plugin.statusBarItems.first.id, 'docker-logs-status');
    });

    test('returns empty when disabled', () {
      plugin.setEnabled(false);
      expect(plugin.statusBarItems, isEmpty);
    });
  });

  group('buildToolPanel', () {
    testWidgets('renders enable switch', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => plugin.buildToolPanel(context),
            ),
          ),
        ),
      );
      expect(find.text('Enable Docker Logs'), findsOneWidget);
    });
  });
}
