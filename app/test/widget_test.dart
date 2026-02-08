import 'package:app/screens/log_viewer.dart';
import 'package:app/services/connection_manager.dart';
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

void main() {
  testWidgets('LogViewerScreen renders header and placeholder', (
    WidgetTester tester,
  ) async {
    // Build the screen with providers but without triggering post-frame WS connect.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ConnectionManager()),
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
      ),
    );

    // Verify the static UI renders before the post-frame callback fires.
    // Landing page shows when no logs and no active connection.
    expect(find.text('Logger'), findsOneWidget);
    expect(find.text('Connect to Server'), findsOneWidget);
    expect(find.text('Quick Start'), findsOneWidget);
  });
}
