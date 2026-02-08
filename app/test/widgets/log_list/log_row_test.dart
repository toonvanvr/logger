import 'package:app/models/log_entry.dart';
import 'package:app/services/session_store.dart';
import 'package:app/theme/theme.dart';
import 'package:app/widgets/log_list/log_row.dart';
import 'package:app/widgets/log_list/session_dot.dart';
import 'package:app/widgets/log_list/severity_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../test_helpers.dart';

LogEntry _makeEntry({
  String id = 'e1',
  String text = 'hello world',
  Severity severity = Severity.info,
  LogType type = LogType.text,
  String sessionId = 'sess-1',
}) {
  return makeTestEntry(
    id: id,
    text: text,
    severity: severity,
    type: type,
    sessionId: sessionId,
  );
}

Widget _wrap(Widget child) {
  return MultiProvider(
    providers: [ChangeNotifierProvider(create: (_) => SessionStore())],
    child: MaterialApp(
      theme: createLoggerTheme(),
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  testWidgets('renders text content', (tester) async {
    await tester.pumpWidget(
      _wrap(LogRow(entry: _makeEntry(text: 'test log message'))),
    );

    // TextRenderer uses RichText, so match via predicate.
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is RichText && w.text.toPlainText().contains('test log message'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('shows severity bar with correct width', (tester) async {
    await tester.pumpWidget(
      _wrap(LogRow(entry: _makeEntry(severity: Severity.error))),
    );

    final bar = tester.widget<SizedBox>(
      find.descendant(
        of: find.byType(SeverityBar),
        matching: find.byType(SizedBox),
      ),
    );
    // error = 4px width
    expect(bar.width, 4);
  });

  testWidgets('shows session dot', (tester) async {
    await tester.pumpWidget(
      _wrap(LogRow(entry: _makeEntry(sessionId: 'sess-42'))),
    );

    expect(find.byType(SessionDot), findsOneWidget);
  });

  testWidgets('new entry has highlight animation', (tester) async {
    await tester.pumpWidget(_wrap(LogRow(entry: _makeEntry(), isNew: true)));

    // At t=0 the entry is transparent (opacity animation starting at 0).
    // Use .first to target the row-level animation Opacity (not copy icon).
    final opacity = tester.widget<Opacity>(find.byType(Opacity).first);
    expect(opacity.opacity, 0.0);

    // After pumping 200ms the entry should be fully visible.
    await tester.pump(const Duration(milliseconds: 200));
    final opacityAfter = tester.widget<Opacity>(find.byType(Opacity).first);
    expect(opacityAfter.opacity, closeTo(1.0, 0.05));
  });
}
