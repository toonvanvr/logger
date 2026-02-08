import 'package:app/models/log_entry.dart';
import 'package:app/services/log_store.dart';
import 'package:app/services/settings_service.dart';
import 'package:app/theme/colors.dart';
import 'package:app/theme/theme.dart';
import 'package:app/widgets/state_view/state_view_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

Widget _wrap({required LogStore logStore, SettingsService? settings}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: logStore),
      ChangeNotifierProvider.value(value: settings ?? SettingsService()),
    ],
    child: MaterialApp(
      theme: createLoggerTheme(),
      home: const Scaffold(body: StateViewSection()),
    ),
  );
}

LogEntry _stateEntry(String key, dynamic value, {String session = 's1'}) {
  return LogEntry(
    id: 'state-$key',
    timestamp: '2026-01-01T00:00:00Z',
    sessionId: session,
    severity: Severity.info,
    type: LogType.state,
    stateKey: key,
    stateValue: value,
  );
}

void main() {
  group('StateViewSection', () {
    // ── Test 1: empty state shows nothing ──

    testWidgets('shows SizedBox.shrink when mergedState is empty', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(logStore: LogStore()));

      // StateViewSection returns SizedBox.shrink — no Container rendered.
      expect(find.text('State'), findsNothing);
    });

    // ── Test 2: shows header text ──

    testWidgets('shows header "State" when state has entries', (tester) async {
      final store = LogStore()..addEntry(_stateEntry('count', 42));
      await tester.pumpWidget(_wrap(logStore: store));

      expect(find.text('State'), findsOneWidget);
    });

    // ── Test 3: count badge ──

    testWidgets('shows count badge with number of state entries', (
      tester,
    ) async {
      final store = LogStore()
        ..addEntry(_stateEntry('a', 'x'))
        ..addEntry(_stateEntry('b', 'y'))
        ..addEntry(_stateEntry('c', 'z'));
      await tester.pumpWidget(_wrap(logStore: store));

      // Badge shows "3" — distinct from card values x/y/z.
      expect(find.text('3'), findsOneWidget);
    });

    // ── Test 4: state cards per key-value pair ──

    testWidgets('shows state cards for each key-value pair', (tester) async {
      final store = LogStore()
        ..addEntry(_stateEntry('user', 'alice'))
        ..addEntry(_stateEntry('mode', 'dark'));
      await tester.pumpWidget(_wrap(logStore: store));

      expect(find.text('user'), findsOneWidget);
      expect(find.text('alice'), findsOneWidget);
      expect(find.text('mode'), findsOneWidget);
      expect(find.text('dark'), findsOneWidget);
    });

    // ── Test 5: collapse/expand toggle ──

    testWidgets('collapse hides cards, expand shows them', (tester) async {
      final store = LogStore()..addEntry(_stateEntry('key', 'val'));
      final settings = SettingsService();
      await tester.pumpWidget(_wrap(logStore: store, settings: settings));

      // Initially expanded — card visible.
      expect(find.text('val'), findsOneWidget);

      // Tap header to collapse.
      await tester.tap(find.text('State'));
      await tester.pump();
      expect(find.text('val'), findsNothing);

      // Tap header to expand again.
      await tester.tap(find.text('State'));
      await tester.pump();
      expect(find.text('val'), findsOneWidget);
    });

    // ── Test 6: bgRaised background ──

    testWidgets('uses LoggerColors.bgRaised background', (tester) async {
      final store = LogStore()..addEntry(_stateEntry('x', 1));
      await tester.pumpWidget(_wrap(logStore: store));

      // Find containers with BoxDecoration whose color is bgRaised.
      final containers = find.byType(Container).evaluate();
      final hasBgRaised = containers.any((e) {
        final w = e.widget as Container;
        final d = w.decoration;
        return d is BoxDecoration && d.color == LoggerColors.bgRaised;
      });
      expect(hasBgRaised, isTrue);
    });
  });
}
