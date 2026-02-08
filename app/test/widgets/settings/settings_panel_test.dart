import 'package:app/models/log_entry.dart';
import 'package:app/plugins/plugin_manifest.dart';
import 'package:app/plugins/plugin_registry.dart';
import 'package:app/plugins/plugin_types.dart';
import 'package:app/theme/theme.dart';
import 'package:app/widgets/settings/settings_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap({required bool isVisible, VoidCallback? onClose}) {
  return MaterialApp(
    theme: createLoggerTheme(),
    home: Scaffold(
      body: Row(
        children: [
          const Expanded(child: SizedBox()),
          SettingsPanel(isVisible: isVisible, onClose: onClose ?? () {}),
        ],
      ),
    ),
  );
}

/// Minimal filter plugin stub for testing tool group rendering.
class _FakeFilter extends FilterPlugin with EnableablePlugin {
  @override
  String get id => 'test.fake_filter';
  @override
  String get name => 'Fake Filter';
  @override
  String get version => '0.0.1';
  @override
  String get description => 'Test filter';
  @override
  PluginManifest get manifest => const PluginManifest(
    id: 'test.fake_filter',
    name: 'Fake Filter',
    version: '0.0.1',
    types: ['filter'],
  );
  @override
  String get filterLabel => 'Fake';
  @override
  IconData get filterIcon => Icons.filter_alt;
  @override
  bool matches(LogEntry entry, String query) => false;
  @override
  List<String> getSuggestions(String q, List<LogEntry> entries) => [];
  @override
  void onRegister(PluginRegistry registry) {}
  @override
  void onDispose() {}
}

void main() {
  setUp(() => PluginRegistry.instance.disposeAll());
  tearDown(() => PluginRegistry.instance.disposeAll());

  group('SettingsPanel', () {
    // ── Test 1: zero-width when hidden ──

    testWidgets('renders as zero-width when isVisible=false', (tester) async {
      await tester.pumpWidget(_wrap(isVisible: false));
      await tester.pumpAndSettle();

      final animated = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );
      expect(animated.constraints?.maxWidth ?? 0, 0);
    });

    // ── Test 2: 300-width when visible ──

    testWidgets('renders as 300-width when isVisible=true', (tester) async {
      await tester.pumpWidget(_wrap(isVisible: true));
      await tester.pumpAndSettle();

      // The panel should occupy 300 logical pixels.
      final size = tester.getSize(find.byType(SettingsPanel));
      expect(size.width, 300);
    });

    // ── Test 3: Settings header ──

    testWidgets('shows header "Settings" text', (tester) async {
      await tester.pumpWidget(_wrap(isVisible: true));
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
    });

    // ── Test 4: close button present ──

    testWidgets('shows close button', (tester) async {
      await tester.pumpWidget(_wrap(isVisible: true));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    // ── Test 5: close button calls onClose ──

    testWidgets('close button calls onClose callback', (tester) async {
      var closed = false;
      await tester.pumpWidget(
        _wrap(
          isVisible: true,
          onClose: () {
            closed = true;
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close));
      expect(closed, isTrue);
    });

    // ── Test 6: tool groups from PluginRegistry ──

    testWidgets('shows tool groups from PluginRegistry', (tester) async {
      PluginRegistry.instance.register(_FakeFilter());

      await tester.pumpWidget(_wrap(isVisible: true));
      await tester.pumpAndSettle();

      // Always-present groups.
      expect(find.text('CONNECTIONS'), findsOneWidget);
      expect(find.text('TOOLS'), findsOneWidget);

      // Filter group appears because a filter plugin was registered.
      expect(find.text('SEARCH & FILTER'), findsOneWidget);
      expect(find.text('Fake Filter'), findsOneWidget);
    });
  });
}
