import 'package:app/services/connection_manager.dart';
import 'package:app/services/log_store.dart';
import 'package:app/services/sticky_state.dart';
import 'package:app/theme/theme.dart';
import 'package:app/widgets/status_bar/status_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

Widget _wrap({LogStore? logStore, ConnectionManager? connMgr, StickyStateService? stickyState}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<LogStore>(create: (_) => logStore ?? LogStore()),
      ChangeNotifierProvider<ConnectionManager>(
        create: (_) => connMgr ?? ConnectionManager(),
      ),
      ChangeNotifierProvider<StickyStateService>(
        create: (_) => stickyState ?? StickyStateService(),
      ),
    ],
    child: MaterialApp(
      theme: createLoggerTheme(),
      home: const Scaffold(body: StatusBar()),
    ),
  );
}

void main() {
  group('StatusBar', () {
    testWidgets('shows entry count', (tester) async {
      await tester.pumpWidget(_wrap());
      expect(find.text('0 entries'), findsOneWidget);
    });

    testWidgets('shows memory estimate', (tester) async {
      await tester.pumpWidget(_wrap());
      expect(find.text('0 B'), findsOneWidget);
    });

    testWidgets('shows disconnected when no connections', (tester) async {
      await tester.pumpWidget(_wrap());
      expect(find.text('disconnected'), findsOneWidget);
    });

    testWidgets('shows storage icon', (tester) async {
      await tester.pumpWidget(_wrap());
      expect(find.byIcon(Icons.storage_outlined), findsOneWidget);
    });

    testWidgets('shows memory icon', (tester) async {
      await tester.pumpWidget(_wrap());
      expect(find.byIcon(Icons.memory_outlined), findsOneWidget);
    });
  });
}
