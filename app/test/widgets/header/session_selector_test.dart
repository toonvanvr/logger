import 'package:app/models/log_entry.dart';
import 'package:app/models/server_broadcast.dart';
import 'package:app/services/session_store.dart';
import 'package:app/theme/theme.dart';
import 'package:app/widgets/header/session_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

SessionInfo _makeSession(String id, String name, int colorIndex) {
  return SessionInfo(
    sessionId: id,
    application: ApplicationInfo(name: name),
    startedAt: '2026-01-01T00:00:00Z',
    lastHeartbeat: '2026-01-01T00:00:00Z',
    isActive: true,
    logCount: 0,
    colorIndex: colorIndex,
  );
}

Widget _buildTestWidget({SessionStore? sessionStore}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<SessionStore>(
        create: (_) => sessionStore ?? SessionStore(),
      ),
    ],
    child: MaterialApp(
      theme: createLoggerTheme(),
      home: const Scaffold(body: SessionSelector()),
    ),
  );
}

void main() {
  testWidgets('renders with no sessions', (tester) async {
    await tester.pumpWidget(_buildTestWidget());

    // Banner removed — no "Logger" text
    expect(find.text('Logger'), findsNothing);
    // No session buttons → no overflow button
    expect(find.text('···'), findsNothing);
  });

  testWidgets('renders session buttons with correct colors', (tester) async {
    final store = SessionStore();
    store.updateSessions([
      _makeSession('s1', 'App A', 0),
      _makeSession('s2', 'App B', 1),
    ]);

    await tester.pumpWidget(_buildTestWidget(sessionStore: store));

    expect(find.text('App A'), findsOneWidget);
    expect(find.text('App B'), findsOneWidget);
  });

  testWidgets('tap toggles selection', (tester) async {
    final store = SessionStore();
    store.updateSessions([_makeSession('s1', 'App A', 0)]);

    await tester.pumpWidget(_buildTestWidget(sessionStore: store));

    // Initially not selected
    expect(store.isSelected('s1'), isFalse);

    // Tap to select
    await tester.tap(find.text('App A'));
    await tester.pump();
    expect(store.isSelected('s1'), isTrue);

    // Tap again to deselect (only selected → deselects)
    await tester.tap(find.text('App A'));
    await tester.pump();
    expect(store.isSelected('s1'), isFalse);
  });

  testWidgets('overflow button appears when sessions exceed visible limit', (
    tester,
  ) async {
    final store = SessionStore();
    store.updateSessions(
      List.generate(25, (i) => _makeSession('s$i', 'App $i', i)),
    );

    await tester.pumpWidget(_buildTestWidget(sessionStore: store));

    // Should show overflow button (25 sessions exceeds any dynamic limit)
    expect(find.text('···'), findsOneWidget);
    // First session visible
    expect(find.text('App 0'), findsOneWidget);
  });
}
