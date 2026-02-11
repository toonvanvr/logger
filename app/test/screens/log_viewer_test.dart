import 'package:app/screens/log_viewer.dart';
import 'package:app/services/connection_manager.dart';
import 'package:app/services/filter_service.dart';
import 'package:app/services/keybind_registry.dart';
import 'package:app/services/log_store.dart';
import 'package:app/services/query_store.dart';
import 'package:app/services/rpc_service.dart';
import 'package:app/services/session_store.dart';
import 'package:app/services/settings_service.dart';
import 'package:app/services/sticky_state.dart';
import 'package:app/services/time_range_service.dart';
import 'package:app/theme/theme.dart';
import 'package:app/widgets/status_bar/status_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

Widget _wrap({LogStore? logStore, SettingsService? settings}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => ConnectionManager()),
      ChangeNotifierProvider(create: (_) => FilterService()),
      ChangeNotifierProvider(create: (_) => KeybindRegistry()),
      ChangeNotifierProvider(create: (_) => logStore ?? LogStore()),
      ChangeNotifierProvider(create: (_) => SessionStore()),
      ChangeNotifierProvider(create: (_) => QueryStore()),
      ChangeNotifierProvider(create: (_) => StickyStateService()),
      ChangeNotifierProvider(create: (_) => RpcService()),
      ChangeNotifierProvider(create: (_) => settings ?? SettingsService()),
      ChangeNotifierProvider(create: (_) => TimeRangeService()),
    ],
    child: MaterialApp(
      theme: createLoggerTheme(),
      home: const LogViewerScreen(serverUrl: null),
    ),
  );
}

void main() {
  group('LogViewerScreen', () {
    testWidgets('builds without error with all providers', (tester) async {
      await tester.pumpWidget(_wrap());
      expect(find.byType(LogViewerScreen), findsOneWidget);
    });

    testWidgets('renders status bar', (tester) async {
      await tester.pumpWidget(_wrap());
      expect(find.byType(StatusBar), findsOneWidget);
    });

    testWidgets('shows landing page when no entries and no connections', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap());
      // Advance past the 500ms landing delay timer
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(find.text('Logger'), findsOneWidget);
      expect(find.text('Connect to Server'), findsOneWidget);
    });

    testWidgets('renders mini title bar in mini mode', (tester) async {
      final settings = SettingsService();
      settings.setMiniMode(true);

      await tester.pumpWidget(_wrap(settings: settings));

      // MiniTitleBar should be present
      expect(find.byType(LogViewerScreen), findsOneWidget);
    });

    testWidgets('renders session selector when not in mini mode', (
      tester,
    ) async {
      final settings = SettingsService();
      settings.setMiniMode(false);

      await tester.pumpWidget(_wrap(settings: settings));
      expect(find.byType(LogViewerScreen), findsOneWidget);
    });
  });
}
