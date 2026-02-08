/// Integration tests for Logger Flutter app.
///
/// Run with: flutter test integration_test/app_test.dart -d linux
///
/// These tests exercise the full UI flow **without** a running server.
/// The [LogViewerScreen] is rendered with `serverUrl: null` so that
/// the post-frame WebSocket connect is skipped; instead we inject
/// data directly via the [LogStore] and [SessionStore] providers.
library;

import 'package:app/models/log_entry.dart';
import 'package:app/models/server_message.dart';
import 'package:app/screens/log_viewer.dart';
import 'package:app/services/log_connection.dart';
import 'package:app/services/log_store.dart';
import 'package:app/services/rpc_service.dart';
import 'package:app/services/session_store.dart';
import 'package:app/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

// ─── Helpers ─────────────────────────────────────────────────────────

/// Build the app under test with all required providers.
Widget buildTestApp({LogStore? logStore, SessionStore? sessionStore}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => LogConnection()),
      ChangeNotifierProvider(create: (_) => logStore ?? LogStore()),
      ChangeNotifierProvider(create: (_) => sessionStore ?? SessionStore()),
      ChangeNotifierProvider(create: (_) => RpcService()),
    ],
    child: MaterialApp(
      theme: createLoggerTheme(),
      home: const LogViewerScreen(serverUrl: null),
    ),
  );
}

/// Create a sample [LogEntry] for testing.
LogEntry sampleEntry({
  String? id,
  String? text,
  Severity severity = Severity.info,
  String sessionId = 'test-session',
  String? section,
  String? groupId,
  GroupAction? groupAction,
  String? groupLabel,
}) {
  return LogEntry(
    id: id ?? 'entry-${DateTime.now().microsecondsSinceEpoch}',
    timestamp: DateTime.now().toIso8601String(),
    sessionId: sessionId,
    severity: severity,
    type: LogType.text,
    application: const ApplicationInfo(name: 'test-app', environment: 'test'),
    text: text ?? 'Test log message',
    section: section,
    groupId: groupId,
    groupAction: groupAction,
    groupLabel: groupLabel,
  );
}

/// Create a sample [SessionInfo] for testing.
SessionInfo sampleSession({
  String sessionId = 'test-session',
  String appName = 'test-app',
  bool isActive = true,
  int colorIndex = 0,
}) {
  final now = DateTime.now().toIso8601String();
  return SessionInfo(
    sessionId: sessionId,
    application: ApplicationInfo(name: appName, environment: 'test'),
    startedAt: now,
    lastHeartbeat: now,
    isActive: isActive,
    logCount: 5,
    colorIndex: colorIndex,
  );
}

// ─── Tests ───────────────────────────────────────────────────────────

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('App launch', () {
    testWidgets('renders main layout components', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Header with app title
      expect(find.text('Logger'), findsOneWidget);

      // Status bar is rendered (entry count visible)
      expect(find.textContaining('entries'), findsOneWidget);
    });

    testWidgets('shows empty state when no logs', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Waiting for logs...'), findsOneWidget);
    });
  });

  group('Log entries', () {
    testWidgets('displays injected log entries', (tester) async {
      final logStore = LogStore();
      logStore.addEntries([
        sampleEntry(id: 'e1', text: 'First log message'),
        sampleEntry(id: 'e2', text: 'Second log message'),
        sampleEntry(id: 'e3', text: 'Third log message'),
      ]);

      await tester.pumpWidget(buildTestApp(logStore: logStore));
      await tester.pumpAndSettle();

      expect(find.text('First log message'), findsOneWidget);
      expect(find.text('Second log message'), findsOneWidget);
      expect(find.text('Third log message'), findsOneWidget);
    });

    testWidgets('displays entries with different severities', (tester) async {
      final logStore = LogStore();
      logStore.addEntries([
        sampleEntry(id: 'e-dbg', text: 'Debug msg', severity: Severity.debug),
        sampleEntry(id: 'e-inf', text: 'Info msg', severity: Severity.info),
        sampleEntry(
          id: 'e-wrn',
          text: 'Warning msg',
          severity: Severity.warning,
        ),
        sampleEntry(id: 'e-err', text: 'Error msg', severity: Severity.error),
      ]);

      await tester.pumpWidget(buildTestApp(logStore: logStore));
      await tester.pumpAndSettle();

      expect(find.text('Debug msg'), findsOneWidget);
      expect(find.text('Info msg'), findsOneWidget);
      expect(find.text('Warning msg'), findsOneWidget);
      expect(find.text('Error msg'), findsOneWidget);
    });
  });

  group('Session selector', () {
    testWidgets('shows sessions in header', (tester) async {
      final sessionStore = SessionStore();
      sessionStore.updateSessions([
        sampleSession(sessionId: 's1', appName: 'frontend'),
        sampleSession(sessionId: 's2', appName: 'backend'),
      ]);

      await tester.pumpWidget(buildTestApp(sessionStore: sessionStore));
      await tester.pumpAndSettle();

      expect(find.text('frontend'), findsOneWidget);
      expect(find.text('backend'), findsOneWidget);
    });

    testWidgets('tapping session toggles selection', (tester) async {
      final sessionStore = SessionStore();
      sessionStore.updateSessions([
        sampleSession(sessionId: 's1', appName: 'my-app'),
      ]);

      await tester.pumpWidget(buildTestApp(sessionStore: sessionStore));
      await tester.pumpAndSettle();

      // Tap the session button
      await tester.tap(find.text('my-app'));
      await tester.pumpAndSettle();

      // After tap, session should be selected
      expect(sessionStore.isSelected('s1'), isTrue);

      // Tap again to deselect
      await tester.tap(find.text('my-app'));
      await tester.pumpAndSettle();

      expect(sessionStore.isSelected('s1'), isFalse);
    });
  });

  group('Filter bar', () {
    testWidgets('filter bar toggles open/closed', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Filter bar should be collapsed initially — search field not visible
      expect(find.byType(TextField), findsNothing);

      // Find and tap the filter toggle button (funnel icon)
      final filterToggle = find.byIcon(Icons.filter_list);
      expect(filterToggle, findsOneWidget);

      await tester.tap(filterToggle);
      await tester.pumpAndSettle();

      // Filter bar should now be expanded — search field visible
      expect(find.byType(TextField), findsOneWidget);

      // Tap again to collapse
      await tester.tap(filterToggle);
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNothing);
    });
  });

  group('Status bar', () {
    testWidgets('shows correct entry count', (tester) async {
      final logStore = LogStore();
      logStore.addEntries([
        sampleEntry(id: 'e1', text: 'Msg 1'),
        sampleEntry(id: 'e2', text: 'Msg 2'),
        sampleEntry(id: 'e3', text: 'Msg 3'),
      ]);

      await tester.pumpWidget(buildTestApp(logStore: logStore));
      await tester.pumpAndSettle();

      expect(find.text('3 entries'), findsOneWidget);
    });

    testWidgets('entry count updates when logs are added', (tester) async {
      final logStore = LogStore();

      await tester.pumpWidget(buildTestApp(logStore: logStore));
      await tester.pumpAndSettle();

      expect(find.text('0 entries'), findsOneWidget);

      // Add entries after initial render
      logStore.addEntries([sampleEntry(id: 'late-1', text: 'Late entry')]);
      await tester.pumpAndSettle();

      expect(find.text('1 entries'), findsOneWidget);
    });
  });

  group('Group collapse/expand', () {
    testWidgets('group entries are shown with label', (tester) async {
      final logStore = LogStore();
      final groupId = 'grp-1';
      logStore.addEntries([
        sampleEntry(
          id: 'g-open',
          groupId: groupId,
          groupAction: GroupAction.open,
          groupLabel: 'My Group',
        ),
        sampleEntry(id: 'g-child', text: 'Child entry', groupId: groupId),
        sampleEntry(
          id: 'g-close',
          groupId: groupId,
          groupAction: GroupAction.close,
        ),
      ]);

      await tester.pumpWidget(buildTestApp(logStore: logStore));
      await tester.pumpAndSettle();

      // Group label should be visible
      expect(find.text('My Group'), findsOneWidget);
      // Child entry should be visible (groups default to expanded)
      expect(find.text('Child entry'), findsOneWidget);
    });
  });
}
