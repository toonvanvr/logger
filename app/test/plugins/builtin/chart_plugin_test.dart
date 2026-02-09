import 'package:app/models/log_entry.dart';
import 'package:app/plugins/builtin/chart_plugin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ─── Helpers ─────────────────────────────────────────────────────────

LogEntry _chartEntry({Map<String, dynamic>? data}) => LogEntry(
  id: 'c1',
  timestamp: '2026-01-01T00:00:00Z',
  sessionId: 's1',
  severity: Severity.info,
  kind: EntryKind.event,
  widget: WidgetPayload(type: 'chart', data: data ?? const {}),
);

/// A wrapper that provides a BuildContext for the plugin renderer.
class _ChartTestHost extends StatelessWidget {
  final ChartRendererPlugin plugin;
  final Map<String, dynamic> data;
  final LogEntry entry;

  const _ChartTestHost({
    required this.plugin,
    required this.data,
    required this.entry,
  });

  @override
  Widget build(BuildContext context) {
    return plugin.buildRenderer(context, data, entry);
  }
}

void main() {
  late ChartRendererPlugin plugin;

  setUp(() {
    plugin = ChartRendererPlugin();
  });

  group('ChartRendererPlugin identity', () {
    test('has correct id', () {
      expect(plugin.id, 'dev.logger.chart-renderer');
    });

    test('has correct name', () {
      expect(plugin.name, 'Chart Renderer');
    });

    test('has correct version', () {
      expect(plugin.version, '1.0.0');
    });

    test('is enabled by default', () {
      expect(plugin.enabled, isTrue);
    });

    test('manifest types contains renderer', () {
      expect(plugin.manifest.types, contains('renderer'));
    });
  });

  group('customTypes', () {
    test('handles chart type', () {
      expect(plugin.customTypes, contains('chart'));
    });

    test('handles sparkline type', () {
      expect(plugin.customTypes, contains('sparkline'));
    });

    test('handles bar_chart type', () {
      expect(plugin.customTypes, contains('bar_chart'));
    });
  });

  group('buildRenderer', () {
    testWidgets('renders bar chart with data', (tester) async {
      final data = {
        'variant': 'bar',
        'title': 'Test Chart',
        'data': [
          {'label': 'A', 'value': 10},
          {'label': 'B', 'value': 20},
          {'label': 'C', 'value': 30},
        ],
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 200,
              child: _ChartTestHost(
                plugin: plugin,
                data: data,
                entry: _chartEntry(data: data),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Test Chart'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(_ChartTestHost),
          matching: find.byType(CustomPaint),
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders sparkline chart', (tester) async {
      final data = {
        'variant': 'sparkline',
        'values': [1, 3, 2, 5, 4],
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 200,
              child: _ChartTestHost(
                plugin: plugin,
                data: data,
                entry: _chartEntry(data: data),
              ),
            ),
          ),
        ),
      );

      expect(
        find.descendant(
          of: find.byType(_ChartTestHost),
          matching: find.byType(CustomPaint),
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders area chart', (tester) async {
      final data = {
        'variant': 'area',
        'values': [10, 30, 20, 50, 40],
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 200,
              child: _ChartTestHost(
                plugin: plugin,
                data: data,
                entry: _chartEntry(data: data),
              ),
            ),
          ),
        ),
      );

      expect(
        find.descendant(
          of: find.byType(_ChartTestHost),
          matching: find.byType(CustomPaint),
        ),
        findsOneWidget,
      );
    });

    testWidgets('defaults to bar variant', (tester) async {
      final data = {
        'data': [
          {'label': 'X', 'value': 5},
        ],
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 200,
              child: _ChartTestHost(
                plugin: plugin,
                data: data,
                entry: _chartEntry(data: data),
              ),
            ),
          ),
        ),
      );

      // No crash — defaults to bar.
      expect(
        find.descendant(
          of: find.byType(_ChartTestHost),
          matching: find.byType(CustomPaint),
        ),
        findsOneWidget,
      );
    });

    testWidgets('handles empty data gracefully', (tester) async {
      final data = <String, dynamic>{};

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 200,
              child: _ChartTestHost(
                plugin: plugin,
                data: data,
                entry: _chartEntry(data: data),
              ),
            ),
          ),
        ),
      );

      // Should render without crash even with no data.
      expect(
        find.descendant(
          of: find.byType(_ChartTestHost),
          matching: find.byType(CustomPaint),
        ),
        findsOneWidget,
      );
    });
  });

  group('buildPreview', () {
    test('returns widget for valid data', () {
      final data = {
        'data': [
          {'value': 1},
          {'value': 2},
          {'value': 3},
        ],
      };
      expect(plugin.buildPreview(data), isNotNull);
    });

    test('returns null for empty data', () {
      expect(plugin.buildPreview({}), isNull);
    });
  });

  group('ChartPainter', () {
    test('shouldRepaint detects changes', () {
      const p1 = ChartPainter(
        variant: 'bar',
        values: [1, 2, 3],
        color: Colors.blue,
        textColor: Colors.grey,
      );
      const p2 = ChartPainter(
        variant: 'sparkline',
        values: [1, 2, 3],
        color: Colors.blue,
        textColor: Colors.grey,
      );
      const p3 = ChartPainter(
        variant: 'bar',
        values: [1, 2, 3],
        color: Colors.blue,
        textColor: Colors.grey,
      );

      expect(p1.shouldRepaint(p2), isTrue);
      expect(p1.shouldRepaint(p3), isFalse);
    });
  });
}
