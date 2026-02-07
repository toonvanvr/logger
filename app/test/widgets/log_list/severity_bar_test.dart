import 'package:app/models/log_entry.dart';
import 'package:app/theme/colors.dart';
import 'package:app/theme/theme.dart';
import 'package:app/widgets/log_list/severity_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: createLoggerTheme(),
    home: Scaffold(body: SizedBox(height: 100, child: child)),
  );
}

void main() {
  group('SeverityBar', () {
    // ── Test 1: width varies by severity ──

    test('width varies by severity level', () {
      final cases = {
        Severity.debug: 1.0,
        Severity.info: 2.0,
        Severity.warning: 3.0,
        Severity.error: 4.0,
        Severity.critical: 5.0,
      };

      for (final entry in cases.entries) {
        final bar = SeverityBar(severity: entry.key);
        expect(
          bar.width,
          entry.value,
          reason: '${entry.key} should have width ${entry.value}',
        );
      }
    });

    // ── Test 2: color matches severity ──

    test('color matches severity', () {
      final cases = {
        Severity.debug: LoggerColors.severityDebugBar,
        Severity.info: LoggerColors.severityInfoBar,
        Severity.warning: LoggerColors.severityWarningBar,
        Severity.error: LoggerColors.severityErrorBar,
        Severity.critical: LoggerColors.severityCriticalBar,
      };

      for (final entry in cases.entries) {
        final bar = SeverityBar(severity: entry.key);
        expect(
          bar.color,
          entry.value,
          reason: '${entry.key} should have correct bar color',
        );
      }
    });

    // ── Test 3: renders as SizedBox with ColoredBox ──

    testWidgets('renders as SizedBox with ColoredBox', (tester) async {
      await tester.pumpWidget(
        _wrap(const SeverityBar(severity: Severity.info)),
      );

      expect(find.byType(SizedBox), findsWidgets);
      expect(find.byType(ColoredBox), findsWidgets);
      // Verify our SeverityBar's ColoredBox has the correct color
      final coloredBoxes = tester.widgetList<ColoredBox>(
        find.byType(ColoredBox),
      );
      expect(
        coloredBoxes.any((cb) => cb.color == LoggerColors.severityInfoBar),
        isTrue,
      );
    });
  });
}
