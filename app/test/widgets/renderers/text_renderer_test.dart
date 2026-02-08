import 'package:app/models/log_entry.dart';
import 'package:app/services/session_store.dart';
import 'package:app/theme/theme.dart';
import 'package:app/widgets/renderers/text_renderer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

LogEntry _makeTextEntry({
  String text = 'hello world',
  ExceptionData? exception,
}) {
  return LogEntry(
    id: 'e1',
    timestamp: '2026-02-07T10:00:00.000Z',
    sessionId: 'sess-1',
    severity: Severity.info,
    type: LogType.text,
    text: text,
    exception: exception,
  );
}

Widget _wrap(Widget child) {
  return MultiProvider(
    providers: [ChangeNotifierProvider(create: (_) => SessionStore())],
    child: MaterialApp(
      theme: createLoggerTheme(),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

void main() {
  testWidgets('renders plain text', (tester) async {
    await tester.pumpWidget(
      _wrap(TextRenderer(entry: _makeTextEntry(text: 'simple log message'))),
    );

    expect(find.byType(RichText), findsOneWidget);
    // The plain text should be present in the rendered output.
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is RichText &&
            w.text.toPlainText().contains('simple log message'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('highlights numbers in text', (tester) async {
    await tester.pumpWidget(
      _wrap(TextRenderer(entry: _makeTextEntry(text: 'count is 42 items'))),
    );

    // The rendered RichText should contain the full text.
    expect(
      find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText().contains('42'),
      ),
      findsOneWidget,
    );

    // Verify "42" is in its own span (syntax highlight splits it out).
    final richText = tester.widget<RichText>(
      find.byWidgetPredicate(
        (w) =>
            w is RichText && w.text.toPlainText().contains('count is 42 items'),
      ),
    );
    final root = richText.text as TextSpan;
    final spans = root.children!.cast<TextSpan>();
    final numberSpan = spans.firstWhere((s) => s.text == '42');
    expect(numberSpan, isNotNull);
  });

  testWidgets('shows stack trace when exception present', (tester) async {
    final exception = ExceptionData(
      type: 'TypeError',
      message: 'null is not an object',
      stackTrace: [
        StackFrame(
          location: SourceLocation(uri: 'app.js', line: 10, column: 5),
        ),
        StackFrame(
          location: SourceLocation(uri: 'vendor.js', line: 1, column: 1),
          isVendor: true,
        ),
      ],
    );

    await tester.pumpWidget(
      _wrap(
        TextRenderer(
          entry: _makeTextEntry(text: 'error occurred', exception: exception),
        ),
      ),
    );

    // Exception type and message should be visible.
    expect(find.textContaining('TypeError'), findsOneWidget);
    expect(find.textContaining('null is not an object'), findsOneWidget);
    // First frame visible.
    expect(find.textContaining('app.js:10:5'), findsOneWidget);
    // Expand-all button visible for remaining frame.
    expect(find.textContaining('▸ all 1'), findsOneWidget);
  });
}
