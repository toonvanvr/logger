import 'package:app/models/log_entry.dart';
import 'package:app/services/settings_service.dart';
import 'package:app/theme/theme.dart';
import 'package:app/widgets/renderers/stack_trace_renderer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

Widget _wrap(Widget child) {
  return ChangeNotifierProvider(
    create: (_) => SettingsService(),
    child: MaterialApp(
      theme: createLoggerTheme(),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

void main() {
  group('StackTraceRenderer', () {
    // ── Test 1: shows exception type and message ──

    testWidgets('shows exception type and message', (tester) async {
      const exception = ExceptionData(
        type: 'TypeError',
        message: 'null is not an object',
      );

      await tester.pumpWidget(
        _wrap(const StackTraceRenderer(exception: exception)),
      );

      expect(
        find.byWidgetPredicate(
          (w) =>
              w is RichText &&
              w.text.toPlainText().contains('TypeError: null is not an object'),
        ),
        findsOneWidget,
      );
    });

    // ── Test 2: shows first frame ──

    testWidgets('shows first frame', (tester) async {
      const exception = ExceptionData(
        type: 'Error',
        message: 'oops',
        stackTrace: 'app.dart:42:5\nlib.dart:10',
      );

      await tester.pumpWidget(
        _wrap(const StackTraceRenderer(exception: exception)),
      );

      // First frame visible
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Text && w.data != null && w.data!.contains('app.dart:42:5'),
        ),
        findsOneWidget,
      );
      // "expand all" button visible
      expect(find.text('▸ all 1'), findsOneWidget);
    });

    // ── Test 3: raw frames render without vendor detection ──

    testWidgets('raw frames render with default style', (tester) async {
      const exception = ExceptionData(
        type: 'Error',
        message: 'fail',
        stackTrace: 'vendor.dart:1',
      );

      await tester.pumpWidget(
        _wrap(const StackTraceRenderer(exception: exception)),
      );

      // Frame should render (raw line used as URI in parsed StackFrame).
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Text && w.data != null && w.data!.contains('vendor.dart:1'),
        ),
        findsOneWidget,
      );
    });
  });
}
