import 'package:app/services/connection_manager.dart';
import 'package:app/services/rpc_service.dart';
import 'package:app/theme/theme.dart';
import 'package:app/widgets/rpc/rpc_panel.dart';
import 'package:app/widgets/rpc/rpc_tool_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

Widget _wrap({required RpcService rpcService, required Widget child}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: rpcService),
      ChangeNotifierProvider(create: (_) => ConnectionManager()),
    ],
    child: MaterialApp(
      theme: createLoggerTheme(),
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  group('RpcPanel', () {
    testWidgets('shows tools grouped by session', (tester) async {
      final rpcService = RpcService();
      rpcService.updateTools('sess-1', [
        const RpcToolInfo(
          name: 'getState',
          description: 'Get current state',
          category: 'getter',
        ),
      ]);
      rpcService.updateTools('sess-2', [
        const RpcToolInfo(
          name: 'resetCache',
          description: 'Reset the cache',
          category: 'tool',
        ),
      ]);

      await tester.pumpWidget(
        _wrap(
          rpcService: rpcService,
          child: RpcPanel(isVisible: true, onClose: () {}),
        ),
      );
      await tester.pumpAndSettle();

      // Session IDs displayed as group headers.
      expect(find.text('sess-1'), findsOneWidget);
      expect(find.text('sess-2'), findsOneWidget);
      // Tool names displayed.
      expect(find.text('getState'), findsOneWidget);
      expect(find.text('resetCache'), findsOneWidget);
    });

    testWidgets('tool tile renders name and description', (tester) async {
      final rpcService = RpcService();
      rpcService.updateTools('sess-1', [
        const RpcToolInfo(
          name: 'fetchLogs',
          description: 'Fetch recent logs',
          category: 'getter',
        ),
      ]);

      await tester.pumpWidget(
        _wrap(
          rpcService: rpcService,
          child: RpcPanel(isVisible: true, onClose: () {}),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('fetchLogs'), findsOneWidget);
      expect(find.text('Fetch recent logs'), findsOneWidget);
      expect(find.byType(RpcToolTile), findsOneWidget);
    });

    testWidgets('invoke button triggers action (starts loading)', (
      tester,
    ) async {
      final rpcService = RpcService();
      rpcService.updateTools('sess-1', [
        const RpcToolInfo(
          name: 'ping',
          description: 'Ping the server',
          category: 'tool',
        ),
      ]);

      await tester.pumpWidget(
        _wrap(
          rpcService: rpcService,
          child: RpcPanel(isVisible: true, onClose: () {}),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the tool tile to invoke.
      await tester.tap(find.text('ping'));
      await tester.pump();

      // Should show loading spinner (CircularProgressIndicator).
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
