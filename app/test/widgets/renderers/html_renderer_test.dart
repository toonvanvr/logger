import 'package:app/models/log_entry.dart';
import 'package:app/theme/theme.dart';
import 'package:app/widgets/renderers/html_renderer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

LogEntry _makeHtmlEntry({String? html}) {
  return LogEntry(
    id: 'e1',
    timestamp: '2026-02-07T12:00:00Z',
    sessionId: 'sess-1',
    severity: Severity.info,
    type: LogType.html,
    html: html,
  );
}

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: createLoggerTheme(),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  group('HtmlRenderer', () {
    // ── Test 1: renders stripped HTML (tags removed) ──

    testWidgets('renders stripped HTML with tags removed', (tester) async {
      await tester.pumpWidget(
        _wrap(
          HtmlRenderer(
            entry: _makeHtmlEntry(html: '<p>Hello <b>world</b></p>'),
          ),
        ),
      );

      // In stripped mode (default), should show text without tags
      expect(
        find.byWidgetPredicate(
          (w) => w is Text && w.data != null && w.data!.contains('Hello world'),
        ),
        findsOneWidget,
      );
    });

    // ── Test 2: raw toggle shows original HTML ──

    testWidgets('raw toggle shows original HTML', (tester) async {
      await tester.pumpWidget(
        _wrap(HtmlRenderer(entry: _makeHtmlEntry(html: '<p>Hello</p>'))),
      );

      // Tap "View raw" to toggle
      await tester.tap(find.text('View raw'));
      await tester.pump();

      // Should show original HTML
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Text && w.data != null && w.data!.contains('<p>Hello</p>'),
        ),
        findsOneWidget,
      );
      // Toggle label should change
      expect(find.text('View stripped'), findsOneWidget);
    });

    // ── Test 3: handles null html field ──

    testWidgets('handles null html field', (tester) async {
      await tester.pumpWidget(
        _wrap(HtmlRenderer(entry: _makeHtmlEntry(html: null))),
      );

      // Should render without error, showing empty content
      expect(find.byType(HtmlRenderer), findsOneWidget);
    });
  });
}
