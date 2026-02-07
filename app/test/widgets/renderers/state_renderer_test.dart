import 'package:app/models/log_entry.dart';
import 'package:app/theme/theme.dart';
import 'package:app/widgets/renderers/state_renderer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

LogEntry _makeStateEntry({String? stateKey, dynamic stateValue}) {
  return LogEntry(
    id: 'e1',
    timestamp: '2026-02-07T12:00:00Z',
    sessionId: 'sess-1',
    severity: Severity.info,
    type: LogType.state,
    stateKey: stateKey,
    stateValue: stateValue,
  );
}

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: createLoggerTheme(),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  group('StateRenderer', () {
    // ── Test 1: shows key = value ──

    testWidgets('shows key and value', (tester) async {
      await tester.pumpWidget(
        _wrap(
          StateRenderer(
            entry: _makeStateEntry(stateKey: 'theme', stateValue: 'dark'),
          ),
        ),
      );

      expect(find.text('theme: '), findsOneWidget);
      expect(find.text('dark'), findsOneWidget);
    });

    // ── Test 2: shows deleted indicator for null value ──

    testWidgets('shows deleted indicator for null value', (tester) async {
      await tester.pumpWidget(
        _wrap(
          StateRenderer(
            entry: _makeStateEntry(stateKey: 'theme', stateValue: null),
          ),
        ),
      );

      expect(find.text('theme: '), findsOneWidget);
      expect(find.text('deleted'), findsOneWidget);
    });

    // ── Test 3: formats object values as JSON ──

    testWidgets('formats object values as JSON', (tester) async {
      await tester.pumpWidget(
        _wrap(
          StateRenderer(
            entry: _makeStateEntry(stateKey: 'config', stateValue: {'a': 1}),
          ),
        ),
      );

      expect(find.text('config: '), findsOneWidget);
      // JSON formatted with indentation
      expect(
        find.byWidgetPredicate(
          (w) => w is Text && w.data != null && w.data!.contains('"a": 1'),
        ),
        findsOneWidget,
      );
    });
  });
}
