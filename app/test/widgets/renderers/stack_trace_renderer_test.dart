import 'package:app/models/log_entry.dart';
import 'package:app/theme/colors.dart';
import 'package:app/theme/theme.dart';
import 'package:app/widgets/renderers/stack_trace_renderer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: createLoggerTheme(),
    home: Scaffold(body: SingleChildScrollView(child: child)),
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
        stackTrace: [
          StackFrame(
            location: SourceLocation(uri: 'app.dart', line: 42, column: 5),
          ),
          StackFrame(location: SourceLocation(uri: 'lib.dart', line: 10)),
        ],
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
      // "1 more frames" link visible
      expect(find.text('1 more frames'), findsOneWidget);
    });

    // ── Test 3: vendor frames are dimmed ──

    testWidgets('vendor frames are dimmed', (tester) async {
      const exception = ExceptionData(
        type: 'Error',
        message: 'fail',
        stackTrace: [
          StackFrame(
            location: SourceLocation(uri: 'vendor.dart', line: 1),
            isVendor: true,
          ),
        ],
      );

      await tester.pumpWidget(
        _wrap(const StackTraceRenderer(exception: exception)),
      );

      // Vendor frame should use fgMuted color
      final vendorText = tester.widget<Text>(
        find.byWidgetPredicate(
          (w) =>
              w is Text && w.data != null && w.data!.contains('vendor.dart:1'),
        ),
      );
      expect(vendorText.style!.color, LoggerColors.fgMuted);
    });
  });
}
