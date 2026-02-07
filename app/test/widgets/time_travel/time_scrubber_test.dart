import 'package:app/theme/theme.dart';
import 'package:app/widgets/time_travel/time_scrubber.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap({required Widget child}) {
  return MaterialApp(
    theme: createLoggerTheme(),
    home: Scaffold(body: child),
  );
}

void main() {
  group('TimeScrubber', () {
    testWidgets('not visible when inactive', (tester) async {
      await tester.pumpWidget(
        _wrap(
          child: const TimeScrubber(
            isActive: false,
            sessionStart: null,
            sessionEnd: null,
          ),
        ),
      );

      // SizedBox.shrink should make height 0.
      expect(find.byType(TimeScrubber), findsOneWidget);
      expect(find.byType(GestureDetector), findsNothing);
    });

    testWidgets('shows time range when active', (tester) async {
      final start = DateTime(2026, 2, 7, 10, 0, 0);
      final end = DateTime(2026, 2, 7, 10, 30, 0);

      await tester.pumpWidget(
        _wrap(
          child: SizedBox(
            width: 400,
            child: TimeScrubber(
              isActive: true,
              sessionStart: start,
              sessionEnd: end,
            ),
          ),
        ),
      );

      // Should display start and end timestamps.
      expect(find.text('10:00:00'), findsOneWidget);
      expect(find.text('10:30:00'), findsOneWidget);
    });

    testWidgets('drag updates thumb position', (tester) async {
      final start = DateTime(2026, 2, 7, 10, 0, 0);
      final end = DateTime(2026, 2, 7, 10, 30, 0);

      DateTime? lastFrom;
      DateTime? lastTo;

      await tester.pumpWidget(
        _wrap(
          child: SizedBox(
            width: 400,
            child: TimeScrubber(
              isActive: true,
              sessionStart: start,
              sessionEnd: end,
              onRangeChanged: (from, to) {
                lastFrom = from;
                lastTo = to;
              },
            ),
          ),
        ),
      );

      // Perform a horizontal drag to the left (decreasing position).
      await tester.drag(find.byType(TimeScrubber), const Offset(-100, 0));
      await tester.pump();

      // The thumb should have moved from 1.0 toward 0.0.
      final state = tester.state<TimeScrubberState>(find.byType(TimeScrubber));
      expect(state.thumbPosition, lessThan(1.0));

      // The range callback should have been called.
      expect(lastFrom, isNotNull);
      expect(lastTo, isNotNull);
      expect(lastTo!.isBefore(end), isTrue);
    });
  });
}
