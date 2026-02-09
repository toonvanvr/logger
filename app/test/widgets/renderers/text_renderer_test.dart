import 'package:app/models/log_entry.dart';
import 'package:app/services/session_store.dart';
import 'package:app/theme/theme.dart';
import 'package:app/widgets/renderers/text_renderer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../test_helpers.dart';

LogEntry _makeTextEntry({
  String message = 'hello world',
  ExceptionData? exception,
}) {
  return makeTestEntry(message: message, exception: exception);
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
      _wrap(TextRenderer(entry: _makeTextEntry(message: 'simple log message'))),
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

  testWidgets('uses Text.rich for SelectionArea compatibility', (tester) async {
    await tester.pumpWidget(
      _wrap(TextRenderer(entry: _makeTextEntry(message: 'selectable text'))),
    );

    // TextRenderer should produce a Text widget (via Text.rich), not a
    // bare RichText, so that it participates in SelectionArea.
    final textWidgets = find.byWidgetPredicate(
      (w) => w is Text && w.textSpan != null,
    );
    expect(textWidgets, findsOneWidget);
  });

  testWidgets('highlights numbers in text', (tester) async {
    await tester.pumpWidget(
      _wrap(TextRenderer(entry: _makeTextEntry(message: 'count is 42 items'))),
    );

    // The rendered output should contain the full text.
    expect(
      find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText().contains('42'),
      ),
      findsOneWidget,
    );

    // Verify "42" is in its own span (syntax highlight splits it out).
    // Text.rich stores our TextSpan on the textSpan property.
    final textWidget = tester.widget<Text>(
      find.byWidgetPredicate(
        (w) =>
            w is Text &&
            w.textSpan != null &&
            w.textSpan!.toPlainText().contains('count is 42 items'),
      ),
    );
    final root = textWidget.textSpan! as TextSpan;
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
          entry: _makeTextEntry(
            message: 'error occurred',
            exception: exception,
          ),
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
