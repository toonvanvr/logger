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
import 'package:app/widgets/log_list/selection_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../test_helpers.dart';

Widget _wrap({LogStore? logStore}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => ConnectionManager()),
      ChangeNotifierProvider(create: (_) => FilterService()),
      ChangeNotifierProvider(create: (_) => logStore ?? LogStore()),
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
  group('LogViewerScreen selection', () {
    testWidgets('builds without error', (tester) async {
      await tester.pumpWidget(_wrap());
      expect(find.byType(LogViewerScreen), findsOneWidget);
    });

    testWidgets('selection actions not visible initially', (tester) async {
      final store = LogStore();
      store.addEntry(makeTestEntry(id: 'e1', message: 'hello'));

      await tester.pumpWidget(_wrap(logStore: store));
      await tester.pumpAndSettle();

      // SelectionActions bar should not be visible without selection
      expect(find.byType(SelectionActions), findsNothing);
    });
  });
}
