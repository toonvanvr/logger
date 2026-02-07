import 'package:app/theme/theme.dart';
import 'package:app/widgets/header/filter_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders severity toggles', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: createLoggerTheme(),
        home: const Scaffold(body: FilterBar()),
      ),
    );

    // 5 severity toggle buttons showing first letter
    expect(find.text('D'), findsOneWidget); // debug
    expect(find.text('I'), findsOneWidget); // info
    expect(find.text('W'), findsOneWidget); // warning
    expect(find.text('E'), findsOneWidget); // error
    expect(find.text('C'), findsOneWidget); // critical
  });

  testWidgets('toggle severity calls onSeverityChange', (tester) async {
    Set<String>? lastSeverities;

    await tester.pumpWidget(
      MaterialApp(
        theme: createLoggerTheme(),
        home: Scaffold(
          body: FilterBar(onSeverityChange: (s) => lastSeverities = s),
        ),
      ),
    );

    // Tap debug toggle to turn it off
    await tester.tap(find.text('D'));
    await tester.pump();

    expect(lastSeverities, isNotNull);
    expect(lastSeverities!.contains('debug'), isFalse);
    expect(lastSeverities!.contains('info'), isTrue);
  });

  testWidgets('text filter emits onTextFilterChange', (tester) async {
    String? lastText;

    await tester.pumpWidget(
      MaterialApp(
        theme: createLoggerTheme(),
        home: Scaffold(
          body: FilterBar(onTextFilterChange: (t) => lastText = t),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'hello');
    expect(lastText, 'hello');
  });
}
