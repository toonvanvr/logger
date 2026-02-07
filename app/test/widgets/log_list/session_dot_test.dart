import 'package:app/models/log_entry.dart';
import 'package:app/models/server_message.dart';
import 'package:app/services/session_store.dart';
import 'package:app/theme/colors.dart';
import 'package:app/theme/theme.dart';
import 'package:app/widgets/log_list/session_dot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

Widget _wrap(Widget child, {SessionStore? store}) {
  return ChangeNotifierProvider(
    create: (_) => store ?? SessionStore(),
    child: MaterialApp(
      theme: createLoggerTheme(),
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  group('SessionDot', () {
    // ── Test 1: renders colored circle ──

    testWidgets('renders colored circle from session color index', (
      tester,
    ) async {
      final store = SessionStore();
      store.updateSession(
        SessionInfo(
          sessionId: 'sess-1',
          application: const ApplicationInfo(name: 'App'),
          startedAt: '2026-02-07T12:00:00Z',
          lastHeartbeat: '2026-02-07T12:01:00Z',
          isActive: true,
          logCount: 0,
          colorIndex: 3,
        ),
      );

      await tester.pumpWidget(
        _wrap(const SessionDot(sessionId: 'sess-1'), store: store),
      );

      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.shape, BoxShape.circle);
      expect(decoration.color, LoggerColors.sessionPool[3]);
    });

    // ── Test 2: default color when session unknown ──

    testWidgets('uses default color when session unknown', (tester) async {
      await tester.pumpWidget(
        _wrap(const SessionDot(sessionId: 'unknown-sess')),
      );

      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration as BoxDecoration;
      // colorIndex defaults to 0 when session is null
      expect(decoration.color, LoggerColors.sessionPool[0]);
    });
  });
}
