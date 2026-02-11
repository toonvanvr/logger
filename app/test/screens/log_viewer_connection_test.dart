import 'package:app/screens/log_viewer.dart';
import 'package:app/services/connection_manager.dart';
import 'package:app/services/filter_service.dart';
import 'package:app/services/log_store.dart';
import 'package:app/services/query_store.dart';
import 'package:app/services/rpc_service.dart';
import 'package:app/services/session_store.dart';
import 'package:app/services/settings_service.dart';
import 'package:app/services/sticky_state.dart';
import 'package:app/services/time_range_service.dart';
import 'package:app/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

Widget _wrap() {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => ConnectionManager()),
      ChangeNotifierProvider(create: (_) => FilterService()),
      ChangeNotifierProvider(create: (_) => LogStore()),
      ChangeNotifierProvider(create: (_) => SessionStore()),
      ChangeNotifierProvider(create: (_) => QueryStore()),
      ChangeNotifierProvider(create: (_) => StickyStateService()),
      ChangeNotifierProvider(create: (_) => RpcService()),
      ChangeNotifierProvider(create: (_) => SettingsService()),
      ChangeNotifierProvider(create: (_) => TimeRangeService()),
    ],
    child: MaterialApp(
      theme: createLoggerTheme(),
      home: const LogViewerScreen(serverUrl: null),
    ),
  );
}

void main() {
  group('LogViewerScreen connection', () {
    testWidgets('builds with null serverUrl (no auto-connect)', (tester) async {
      await tester.pumpWidget(_wrap());
      expect(find.byType(LogViewerScreen), findsOneWidget);
    });

    testWidgets('shows landing page when disconnected and no entries', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap());
      // Advance past the 500ms landing delay timer
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      // Landing page shows connect prompt
      expect(find.text('Connect to Server'), findsOneWidget);
    });

    testWidgets('renders Scaffold as root widget', (tester) async {
      await tester.pumpWidget(_wrap());
      expect(find.byType(Scaffold), findsOneWidget);
    });
  });
}
