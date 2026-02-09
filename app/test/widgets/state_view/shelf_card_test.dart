import 'package:app/theme/theme.dart';
import 'package:app/widgets/state_view/shelf_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ShelfCard', () {
    testWidgets('renders key without _shelf. prefix and value', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: createLoggerTheme(),
          home: const Scaffold(
            body: ShelfCard(stateKey: '_shelf.env', stateValue: 'production'),
          ),
        ),
      );

      expect(find.text('env'), findsOneWidget);
      expect(find.text('production'), findsOneWidget);
    });

    testWidgets('onTap callback fires', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: createLoggerTheme(),
          home: Scaffold(
            body: ShelfCard(
              stateKey: '_shelf.key',
              stateValue: 'val',
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ShelfCard));
      expect(tapped, isTrue);
    });

    testWidgets('shows click cursor when onTap provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: createLoggerTheme(),
          home: Scaffold(
            body: ShelfCard(
              stateKey: '_shelf.a',
              stateValue: 'b',
              onTap: () {},
            ),
          ),
        ),
      );

      final mouseRegion = tester.widget<MouseRegion>(
        find.descendant(
          of: find.byType(ShelfCard),
          matching: find.byType(MouseRegion),
        ),
      );
      expect(mouseRegion.cursor, SystemMouseCursors.click);
    });

    testWidgets('shows basic cursor when onTap is null', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: createLoggerTheme(),
          home: const Scaffold(
            body: ShelfCard(stateKey: '_shelf.a', stateValue: 'b'),
          ),
        ),
      );

      final mouseRegion = tester.widget<MouseRegion>(
        find.descendant(
          of: find.byType(ShelfCard),
          matching: find.byType(MouseRegion),
        ),
      );
      expect(mouseRegion.cursor, SystemMouseCursors.basic);
    });

    testWidgets('truncates long values', (tester) async {
      final longValue = 'x' * 200;

      await tester.pumpWidget(
        MaterialApp(
          theme: createLoggerTheme(),
          home: Scaffold(
            body: ShelfCard(stateKey: '_shelf.long', stateValue: longValue),
          ),
        ),
      );

      // Value should be truncated to 120 chars + ellipsis
      expect(find.textContaining('…'), findsOneWidget);
    });

    testWidgets('renders null value as "null"', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: createLoggerTheme(),
          home: const Scaffold(
            body: ShelfCard(stateKey: '_shelf.empty', stateValue: null),
          ),
        ),
      );

      expect(find.text('null'), findsOneWidget);
    });
  });
}
