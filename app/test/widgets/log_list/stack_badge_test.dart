import 'package:app/theme/theme.dart';
import 'package:app/widgets/log_list/stack_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: createLoggerTheme(),
    home: Scaffold(body: child),
  );
}

void main() {
  group('StackBadge', () {
    testWidgets('renders ×N text for depth > 1', (tester) async {
      await tester.pumpWidget(_wrap(const StackBadge(depth: 5)));
      expect(find.text('×5'), findsOneWidget);
    });

    testWidgets('hidden when depth <= 1', (tester) async {
      await tester.pumpWidget(_wrap(const StackBadge(depth: 1)));
      expect(find.text('×1'), findsNothing);
      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('hidden when depth is 0', (tester) async {
      await tester.pumpWidget(_wrap(const StackBadge(depth: 0)));
      expect(find.text('×0'), findsNothing);
    });

    testWidgets('tap calls callback', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(StackBadge(depth: 3, onTap: () => tapped = true)),
      );

      await tester.tap(find.text('×3'));
      expect(tapped, isTrue);
    });

    testWidgets('renders with pill shape decoration', (tester) async {
      await tester.pumpWidget(_wrap(const StackBadge(depth: 10)));

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(StackBadge),
          matching: find.byType(Container),
        ),
      );
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(7));
    });
  });
}
