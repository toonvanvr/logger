import 'package:app/theme/colors.dart';
import 'package:app/theme/theme.dart';
import 'package:app/widgets/log_list/stack_timeline.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: createLoggerTheme(),
    home: Scaffold(
      body: Center(child: SizedBox(width: 400, child: child)),
    ),
  );
}

void main() {
  group('StackTimeline', () {
    testWidgets('renders N dots for count <= 20', (tester) async {
      await tester.pumpWidget(
        _wrap(const StackTimeline(count: 5, activeIndex: 2)),
      );

      // Should find 5 dot containers
      final dots = tester.widgetList<Container>(
        find.descendant(
          of: find.byType(StackTimeline),
          matching: find.byType(Container),
        ),
      );
      // Filter to circular dots only
      final circularDots = dots.where((c) {
        final dec = c.decoration;
        return dec is BoxDecoration && dec.shape == BoxShape.circle;
      }).toList();
      expect(circularDots.length, 5);
    });

    testWidgets('active dot is highlighted', (tester) async {
      await tester.pumpWidget(
        _wrap(const StackTimeline(count: 3, activeIndex: 1)),
      );

      final dots = tester
          .widgetList<Container>(
            find.descendant(
              of: find.byType(StackTimeline),
              matching: find.byType(Container),
            ),
          )
          .where((c) {
            final dec = c.decoration;
            return dec is BoxDecoration && dec.shape == BoxShape.circle;
          })
          .toList();

      // Active dot (index 1) should have borderFocus color
      final activeDec = dots[1].decoration! as BoxDecoration;
      expect(activeDec.color, LoggerColors.borderFocus);

      // Inactive dots should have fgMuted color
      final inactiveDec = dots[0].decoration! as BoxDecoration;
      expect(inactiveDec.color, LoggerColors.fgMuted);
    });

    testWidgets('tap selects version', (tester) async {
      int? selected;
      await tester.pumpWidget(
        _wrap(
          StackTimeline(
            count: 4,
            activeIndex: 0,
            onSelect: (i) => selected = i,
          ),
        ),
      );

      // Tap the third dot (index 2)
      final gestures = tester
          .widgetList<GestureDetector>(
            find.descendant(
              of: find.byType(StackTimeline),
              matching: find.byType(GestureDetector),
            ),
          )
          .toList();
      await tester.tap(find.byWidget(gestures[2]));
      expect(selected, 2);
    });

    testWidgets('renders condensed mode for count > 20', (tester) async {
      await tester.pumpWidget(
        _wrap(const StackTimeline(count: 25, activeIndex: 10)),
      );

      // Should render a Slider instead of dots
      expect(find.byType(Slider), findsOneWidget);
      // Should show range labels
      expect(find.text('1'), findsOneWidget);
      expect(find.text('25'), findsOneWidget);
    });

    testWidgets('hidden when count <= 0', (tester) async {
      await tester.pumpWidget(
        _wrap(const StackTimeline(count: 0, activeIndex: 0)),
      );
      expect(find.byType(SizedBox), findsWidgets);
    });
  });
}
