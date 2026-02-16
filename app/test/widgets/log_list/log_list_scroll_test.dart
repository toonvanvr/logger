import 'package:app/models/log_entry.dart';
import 'package:app/services/log_store.dart';
import 'package:app/services/session_store.dart';
import 'package:app/services/sticky_state.dart';
import 'package:app/services/time_range_service.dart';
import 'package:app/theme/theme.dart';
import 'package:app/widgets/log_list/live_pill.dart';
import 'package:app/widgets/log_list/log_list_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../test_helpers.dart';

Widget _wrap({required LogStore logStore}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: logStore),
      ChangeNotifierProvider(create: (_) => SessionStore()),
      ChangeNotifierProvider(create: (_) => StickyStateService()),
      ChangeNotifierProvider(create: (_) => TimeRangeService()),
    ],
    child: MaterialApp(
      theme: createLoggerTheme(),
      home: const Scaffold(body: LogListView()),
    ),
  );
}

void main() {
  group('LogListView scroll behavior', () {
    testWidgets('shows LIVE pill when list has entries', (tester) async {
      final store = LogStore();
      for (var i = 0; i < 5; i++) {
        store.addEntry(
          makeTestEntry(
            id: 'e$i',
            message: 'log line $i',
            severity: Severity.info,
          ),
        );
      }

      await tester.pumpWidget(_wrap(logStore: store));
      await tester.pumpAndSettle();

      expect(find.byType(LivePill), findsOneWidget);
    });

    testWidgets('no LIVE pill on empty list', (tester) async {
      await tester.pumpWidget(_wrap(logStore: LogStore()));
      expect(find.byType(LivePill), findsNothing);
    });

    testWidgets('renders with many entries without overflow', (tester) async {
      final store = LogStore();
      for (var i = 0; i < 50; i++) {
        store.addEntry(
          makeTestEntry(
            id: 'e$i',
            message: 'log $i',
            severity: i.isEven ? Severity.info : Severity.debug,
          ),
        );
      }

      await tester.pumpWidget(_wrap(logStore: store));
      await tester.pumpAndSettle();

      expect(find.byType(LogListView), findsOneWidget);
    });

    testWidgets(
      'stays paused at bottom until explicit resume when unseen logs exist',
      (tester) async {
        final store = LogStore();
        for (var i = 0; i < 120; i++) {
          store.addEntry(
            makeTestEntry(
              id: 'seed-$i',
              message: 'seed log $i',
              severity: Severity.info,
            ),
          );
        }

        await tester.pumpWidget(_wrap(logStore: store));
        await tester.pumpAndSettle();

        // Move away from bottom to enter paused mode.
        await tester.drag(find.byType(ListView), const Offset(0, 400));
        await tester.pumpAndSettle();

        // Ingest new logs while paused.
        for (var i = 0; i < 5; i++) {
          store.addEntry(
            makeTestEntry(
              id: 'new-$i',
              message: 'new log $i',
              severity: Severity.info,
            ),
          );
        }
        await tester.pumpAndSettle();

        expect(find.text('5 new'), findsOneWidget);
        expect(find.byType(LivePill), findsNothing);

        // Scrolling back to the bottom should not implicitly resume LIVE.
        await tester.drag(find.byType(ListView), const Offset(0, -10000));
        await tester.pumpAndSettle();

        expect(find.text('5 new'), findsOneWidget);
        expect(find.byType(LivePill), findsNothing);

        // Explicit resume should switch to LIVE mode.
        await tester.tap(find.text('5 new'));
        await tester.pumpAndSettle();

        expect(find.byType(LivePill), findsOneWidget);
      },
    );
  });
}
