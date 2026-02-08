import 'package:app/widgets/state_view/state_chart_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StateChartStrip', () {
    testWidgets('renders SizedBox.shrink when chartEntries is empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: StateChartStrip(chartEntries: {})),
        ),
      );

      expect(find.byType(ListView), findsNothing);
    });

    testWidgets('renders chart cards for valid chart data', (tester) async {
      final entries = <String, dynamic>{
        '_chart.heap': {
          'type': 'area',
          'values': [10, 20, 30, 40],
          'title': 'Heap MB',
        },
        '_chart.requests': {
          'type': 'bar',
          'values': [5, 15, 25],
          'title': 'Req/s',
        },
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: StateChartStrip(chartEntries: entries)),
        ),
      );

      expect(find.byType(ListView), findsOneWidget);
      expect(find.text('Heap MB'), findsOneWidget);
      expect(find.text('Req/s'), findsOneWidget);
    });

    testWidgets('skips entries with invalid chart data', (tester) async {
      final entries = <String, dynamic>{
        '_chart.valid': {
          'type': 'bar',
          'values': [10, 20, 30],
          'title': 'Valid',
        },
        '_chart.invalid': 'not a map',
        '_chart.tooFew': {
          'type': 'bar',
          'values': [10],
        },
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: StateChartStrip(chartEntries: entries)),
        ),
      );

      expect(find.text('Valid'), findsOneWidget);
      // Invalid entries render SizedBox.shrink, not crash
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders chart without title when title is null', (
      tester,
    ) async {
      final entries = <String, dynamic>{
        '_chart.noTitle': {
          'type': 'sparkline',
          'values': [1, 2, 3, 4, 5],
        },
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: StateChartStrip(chartEntries: entries)),
        ),
      );

      // Chart strip renders with a ListView containing the chart
      expect(find.byType(ListView), findsOneWidget);
    });
  });
}
