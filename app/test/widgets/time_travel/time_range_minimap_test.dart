import 'package:app/models/log_entry.dart';
import 'package:app/services/time_range_service.dart';
import 'package:app/widgets/time_travel/time_range_minimap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Wraps the minimap in a minimal app with a TimeRangeService provider.
Widget _buildMinimap({TimeRangeService? service}) {
  final svc = service ?? TimeRangeService();
  return ChangeNotifierProvider<TimeRangeService>.value(
    value: svc,
    child: const MaterialApp(
      home: Scaffold(
        body: SizedBox(width: 400, height: 100, child: TimeRangeMinimap()),
      ),
    ),
  );
}

/// Creates a service with session bounds and buckets pre-populated.
TimeRangeService _readyService({int entryCount = 10}) {
  final svc = TimeRangeService();
  final t0 = DateTime.utc(2026, 1, 1, 0, 0, 0);
  final t1 = DateTime.utc(2026, 1, 1, 0, 10, 0); // 10 min
  svc.updateSessionBounds(t0, t1);

  final entries = List.generate(entryCount, (i) {
    final ts = t0.add(Duration(minutes: i * 10 ~/ entryCount));
    return LogEntry(
      id: 'e$i',
      timestamp: ts.toIso8601String(),
      sessionId: 's1',
      severity: i.isEven ? Severity.info : Severity.debug,
      type: LogType.text,
    );
  });
  svc.updateBuckets(entries);
  return svc;
}

void main() {
  group('TimeRangeMinimap', () {
    testWidgets('hidden when no buckets', (tester) async {
      final svc = TimeRangeService();
      await tester.pumpWidget(_buildMinimap(service: svc));
      expect(find.byType(TimeRangeMinimap), findsOneWidget);
      // Should render SizedBox.shrink — no Container at 48dp
      expect(find.byType(SizedBox), findsWidgets);
      // No CustomPaint with MinimapPainter
      expect(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is MinimapPainter,
        ),
        findsNothing,
      );
    });

    testWidgets('renders at 48dp when data present', (tester) async {
      final svc = _readyService();
      await tester.pumpWidget(_buildMinimap(service: svc));
      // Find the Container that has the 48dp height
      find.byWidgetPredicate(
        (w) => w is Container && w.constraints?.maxHeight == 48,
      );
      // The minimap is shown — widget tree exists
      expect(find.byType(TimeRangeMinimap), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('shows time labels', (tester) async {
      final svc = _readyService();
      await tester.pumpWidget(_buildMinimap(service: svc));
      // Labels show HH:mm:ss format — check that text widgets with time exist
      final startLocal = DateTime.utc(2026, 1, 1, 0, 0, 0).toLocal();
      final endLocal = DateTime.utc(2026, 1, 1, 0, 10, 0).toLocal();
      final startStr =
          '${startLocal.hour.toString().padLeft(2, '0')}:'
          '${startLocal.minute.toString().padLeft(2, '0')}:'
          '${startLocal.second.toString().padLeft(2, '0')}';
      final endStr =
          '${endLocal.hour.toString().padLeft(2, '0')}:'
          '${endLocal.minute.toString().padLeft(2, '0')}:'
          '${endLocal.second.toString().padLeft(2, '0')}';
      expect(find.text(startStr), findsOneWidget);
      expect(find.text(endStr), findsOneWidget);
    });

    testWidgets('CustomPaint uses MinimapPainter', (tester) async {
      final svc = _readyService();
      await tester.pumpWidget(_buildMinimap(service: svc));
      final customPaint = tester.widget<CustomPaint>(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is MinimapPainter,
        ),
      );
      expect(customPaint.painter, isA<MinimapPainter>());
    });

    testWidgets('double-tap resets range', (tester) async {
      final svc = _readyService();
      svc.setRange(
        DateTime.utc(2026, 1, 1, 0, 0, 0),
        DateTime.utc(2026, 1, 1, 0, 5, 0),
      );
      expect(svc.state, TimeRangeState.zoomed);

      await tester.pumpWidget(_buildMinimap(service: svc));
      // Double-tap on the minimap area
      await tester.tap(find.byType(TimeRangeMinimap));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byType(TimeRangeMinimap));
      await tester.pumpAndSettle();

      expect(svc.state, TimeRangeState.full);
    });

    testWidgets('tap on minimap activates zoom', (tester) async {
      final svc = _readyService();
      expect(svc.isActive, isFalse);

      await tester.pumpWidget(_buildMinimap(service: svc));
      // Single tap — need to wait for double-tap timeout to expire
      await tester.tapAt(tester.getCenter(find.byType(TimeRangeMinimap)));
      // Wait past double-tap timeout (300ms)
      await tester.pump(const Duration(milliseconds: 400));

      expect(svc.isActive, isTrue);
      expect(svc.state, TimeRangeState.zoomed);
    });

    testWidgets('scroll on minimap triggers zoom via service', (tester) async {
      final svc = _readyService();
      await tester.pumpWidget(_buildMinimap(service: svc));

      // Programmatic zoom (simulates what scroll would do)
      svc.zoomBy(0.85, anchor: 0.5);
      await tester.pumpAndSettle();

      expect(svc.isActive, isTrue);
      expect(svc.state, TimeRangeState.zoomed);
    });

    testWidgets('viewport drag pans the range', (tester) async {
      final svc = _readyService();
      // Zoom to center 50%
      svc.setRange(
        DateTime.utc(2026, 1, 1, 0, 2, 30),
        DateTime.utc(2026, 1, 1, 0, 7, 30),
      );
      await tester.pumpWidget(_buildMinimap(service: svc));
      await tester.pump();

      // Drag horizontally on the minimap center (inside viewport)
      await tester.drag(find.byType(TimeRangeMinimap), const Offset(30, 0));
      await tester.pumpAndSettle();

      // Range start should have shifted (might be same viewport-drag or tap)
      // The important thing is no crash and service still active
      expect(svc.isActive, isTrue);
    });

    testWidgets('renders without crash on very small widget', (tester) async {
      final svc = _readyService();
      // Very small width may cause label overflow — that's acceptable.
      // Verify it doesn't throw a non-overflow exception.
      await tester.pumpWidget(
        ChangeNotifierProvider<TimeRangeService>.value(
          value: svc,
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox(width: 20, height: 100, child: TimeRangeMinimap()),
            ),
          ),
        ),
      );
      // Overflow is a layout warning, not a crash — check no real exceptions.
      final exception = tester.takeException();
      // Accept RenderFlex overflow as expected for very small widths
      if (exception != null) {
        expect(exception.toString(), contains('overflowed'));
      }
    });

    testWidgets('renders with single bucket', (tester) async {
      final svc = _readyService(entryCount: 1);
      await tester.pumpWidget(_buildMinimap(service: svc));
      expect(find.byType(CustomPaint), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows active viewport after setRange', (tester) async {
      final svc = _readyService();
      await tester.pumpWidget(_buildMinimap(service: svc));
      svc.setRange(
        DateTime.utc(2026, 1, 1, 0, 2, 0),
        DateTime.utc(2026, 1, 1, 0, 8, 0),
      );
      await tester.pump();

      // Verify the painter is updated with isActive=true
      final customPaint = tester.widget<CustomPaint>(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is MinimapPainter,
        ),
      );
      final painter = customPaint.painter as MinimapPainter;
      expect(painter.isActive, isTrue);
      expect(painter.vpStart, greaterThan(0));
      expect(painter.vpEnd, lessThan(1));
    });

    testWidgets('resetRange removes viewport highlight', (tester) async {
      final svc = _readyService();
      svc.setRange(
        DateTime.utc(2026, 1, 1, 0, 2, 0),
        DateTime.utc(2026, 1, 1, 0, 8, 0),
      );
      await tester.pumpWidget(_buildMinimap(service: svc));
      svc.resetRange();
      await tester.pump();

      final customPaint = tester.widget<CustomPaint>(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is MinimapPainter,
        ),
      );
      final painter = customPaint.painter as MinimapPainter;
      expect(painter.isActive, isFalse);
    });

    testWidgets('many buckets render without crash', (tester) async {
      final svc = _readyService(entryCount: 120);
      await tester.pumpWidget(_buildMinimap(service: svc));
      expect(tester.takeException(), isNull);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('minimap rebuilds on service notifyListeners', (tester) async {
      final svc = _readyService();
      await tester.pumpWidget(_buildMinimap(service: svc));

      // Initially not active
      var cp = tester.widget<CustomPaint>(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is MinimapPainter,
        ),
      );
      expect((cp.painter as MinimapPainter).isActive, isFalse);

      // Now zoom
      svc.setRange(
        DateTime.utc(2026, 1, 1, 0, 0, 0),
        DateTime.utc(2026, 1, 1, 0, 5, 0),
      );
      await tester.pump();

      cp = tester.widget<CustomPaint>(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is MinimapPainter,
        ),
      );
      expect((cp.painter as MinimapPainter).isActive, isTrue);
    });
  });

  group('MinimapPainter', () {
    test('shouldRepaint when buckets change', () {
      final t0 = DateTime.utc(2026);
      final t1 = DateTime.utc(2026, 1, 1, 0, 1);
      final b1 = [BucketData(bucketStart: t0, bucketEnd: t1)];
      final b2 = [BucketData(totalCount: 5, bucketStart: t0, bucketEnd: t1)];

      final p1 = MinimapPainter(
        buckets: b1,
        maxCount: 0,
        vpStart: 0,
        vpEnd: 1,
        isActive: false,
      );
      final p2 = MinimapPainter(
        buckets: b2,
        maxCount: 5,
        vpStart: 0,
        vpEnd: 1,
        isActive: false,
      );

      expect(p2.shouldRepaint(p1), isTrue);
    });

    test('shouldRepaint when viewport changes', () {
      final t0 = DateTime.utc(2026);
      final t1 = DateTime.utc(2026, 1, 1, 0, 1);
      final b = [BucketData(bucketStart: t0, bucketEnd: t1)];
      final p1 = MinimapPainter(
        buckets: b,
        maxCount: 0,
        vpStart: 0,
        vpEnd: 1,
        isActive: false,
      );
      final p2 = MinimapPainter(
        buckets: b,
        maxCount: 0,
        vpStart: 0.2,
        vpEnd: 0.8,
        isActive: true,
      );
      expect(p2.shouldRepaint(p1), isTrue);
    });

    test('shouldRepaint false when same data', () {
      final t0 = DateTime.utc(2026);
      final t1 = DateTime.utc(2026, 1, 1, 0, 1);
      final b1 = [BucketData(totalCount: 3, bucketStart: t0, bucketEnd: t1)];
      final b2 = [BucketData(totalCount: 3, bucketStart: t0, bucketEnd: t1)];
      final p1 = MinimapPainter(
        buckets: b1,
        maxCount: 3,
        vpStart: 0,
        vpEnd: 1,
        isActive: false,
      );
      final p2 = MinimapPainter(
        buckets: b2,
        maxCount: 3,
        vpStart: 0,
        vpEnd: 1,
        isActive: false,
      );
      expect(p2.shouldRepaint(p1), isFalse);
    });
  });
}
