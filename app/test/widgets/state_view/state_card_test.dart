import 'package:app/theme/theme.dart';
import 'package:app/widgets/state_view/state_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StateCard', () {
    testWidgets('renders key and value text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: createLoggerTheme(),
          home: const Scaffold(
            body: StateCard(stateKey: 'env', stateValue: 'production'),
          ),
        ),
      );

      expect(find.text('env'), findsOneWidget);
      expect(find.text('production'), findsOneWidget);
    });

    testWidgets('tapping calls onTap callback', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: createLoggerTheme(),
          home: Scaffold(
            body: StateCard(
              stateKey: 'count',
              stateValue: 42,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('count'));
      expect(tapped, isTrue);
    });

    testWidgets('shows click cursor when onTap is provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: createLoggerTheme(),
          home: Scaffold(
            body: StateCard(stateKey: 'key', stateValue: 'val', onTap: () {}),
          ),
        ),
      );

      final mouseRegion = tester.widget<MouseRegion>(
        find.descendant(
          of: find.byType(StateCard),
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
            body: StateCard(stateKey: 'key', stateValue: 'val'),
          ),
        ),
      );

      final mouseRegion = tester.widget<MouseRegion>(
        find.descendant(
          of: find.byType(StateCard),
          matching: find.byType(MouseRegion),
        ),
      );
      expect(mouseRegion.cursor, SystemMouseCursors.basic);
    });

    testWidgets('renders null value as "null"', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: createLoggerTheme(),
          home: const Scaffold(
            body: StateCard(stateKey: 'empty', stateValue: null),
          ),
        ),
      );

      expect(find.text('null'), findsOneWidget);
    });
  });
}
