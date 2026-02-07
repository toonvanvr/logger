import 'package:app/theme/theme.dart';
import 'package:app/widgets/log_list/live_pill.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: createLoggerTheme(),
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  group('LivePill', () {
    // ── Test 1: shows LIVE text ──

    testWidgets('shows LIVE text', (tester) async {
      await tester.pumpWidget(_wrap(const LivePill()));

      expect(find.text('LIVE'), findsOneWidget);
    });
  });

  group('NewLogsButton', () {
    // ── Test 2: shows count ──

    testWidgets('shows count', (tester) async {
      await tester.pumpWidget(_wrap(NewLogsButton(count: 42, onTap: () {})));

      expect(find.text('42 new'), findsOneWidget);
    });

    // ── Test 3: tap fires callback ──

    testWidgets('tap fires callback', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        _wrap(NewLogsButton(count: 5, onTap: () => tapped = true)),
      );

      await tester.tap(find.text('5 new'));
      expect(tapped, isTrue);
    });
  });
}
