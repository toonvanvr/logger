import 'package:app/models/log_entry.dart';
import 'package:app/services/time_range_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers.dart';

/// Helper to create a minimal LogEntry with given timestamp and severity.
LogEntry _entry(String iso, {Severity severity = Severity.info}) {
  return makeTestEntry(
    id: iso,
    timestamp: iso,
    sessionId: 's1',
    severity: severity,
  );
}

void main() {
  group('TimeRangeService', () {
    late TimeRangeService service;

    final t0 = DateTime.utc(2026, 1, 1, 0, 0, 0);
    final t1 = DateTime.utc(2026, 1, 1, 0, 1, 0); // +1 min
    final t2 = DateTime.utc(2026, 1, 1, 0, 2, 0); // +2 min

    setUp(() {
      service = TimeRangeService();
    });

    test('initial state is FULL with no session bounds', () {
      expect(service.state, TimeRangeState.full);
      expect(service.sessionStart, isNull);
      expect(service.sessionEnd, isNull);
      expect(service.isActive, isFalse);
      expect(service.buckets, isEmpty);
    });

    test('updateSessionBounds sets start and end', () {
      service.updateSessionBounds(t0, t2);
      expect(service.sessionStart, t0);
      expect(service.sessionEnd, t2);
    });

    test('setRange transitions to ZOOMED', () {
      service.updateSessionBounds(t0, t2);
      service.setRange(t0, t1);
      expect(service.state, TimeRangeState.zoomed);
      expect(service.isActive, isTrue);
      expect(service.rangeStart, t0);
      expect(service.rangeEnd, t1);
    });

    test('setRange auto-swaps inverted start/end', () {
      service.updateSessionBounds(t0, t2);
      service.setRange(t1, t0); // inverted
      expect(service.rangeStart, t0);
      expect(service.rangeEnd, t1);
    });

    test('setRange clamps to session bounds', () {
      service.updateSessionBounds(t0, t2);
      final before = t0.subtract(const Duration(minutes: 5));
      final after = t2.add(const Duration(minutes: 5));
      service.setRange(before, after);
      expect(service.rangeStart, t0);
      expect(service.rangeEnd, t2);
    });

    test('setRange enforces minimum range of 1 second', () {
      service.updateSessionBounds(t0, t2);
      final almostSame = t0.add(const Duration(milliseconds: 100));
      service.setRange(t0, almostSame);
      final dur = service.rangeEnd!.difference(service.rangeStart!);
      expect(dur.inSeconds, greaterThanOrEqualTo(1));
    });

    test('setRange is a no-op without session bounds', () {
      service.setRange(t0, t1);
      expect(service.state, TimeRangeState.full);
    });

    test('resetRange returns to FULL', () {
      service.updateSessionBounds(t0, t2);
      service.setRange(t0, t1);
      expect(service.state, TimeRangeState.zoomed);
      service.resetRange();
      expect(service.state, TimeRangeState.full);
      expect(service.isActive, isFalse);
    });

    test('viewportStartNorm and viewportEndNorm in FULL state', () {
      service.updateSessionBounds(t0, t2);
      expect(service.viewportStartNorm, 0.0);
      expect(service.viewportEndNorm, 1.0);
    });

    test('viewportStartNorm and viewportEndNorm in ZOOMED', () {
      service.updateSessionBounds(t0, t2);
      service.setRange(t0, t1); // first half of 0-2 min range
      expect(service.viewportStartNorm, closeTo(0.0, 0.01));
      expect(service.viewportEndNorm, closeTo(0.5, 0.01));
    });

    test('zoomBy zooms in (factor < 1)', () {
      service.updateSessionBounds(t0, t2);
      service.setRange(t0, t2); // start from full range
      service.zoomBy(0.5); // zoom in to 50%
      expect(service.state, TimeRangeState.zoomed);
      final dur = service.rangeEnd!.difference(service.rangeStart!);
      // Should be ~60 seconds (50% of 120s)
      expect(dur.inSeconds, closeTo(60, 2));
    });

    test('zoomBy zooms out past full range resets to FULL', () {
      service.updateSessionBounds(t0, t2);
      service.setRange(t0, t1);
      service.zoomBy(10.0); // zoom out way past full
      expect(service.state, TimeRangeState.full);
    });

    test('zoomBy respects minimum range', () {
      service.updateSessionBounds(t0, t2);
      service.setRange(t0, t0.add(const Duration(seconds: 2)));
      service.zoomBy(0.01); // try to zoom to near-zero
      final dur = service.rangeEnd!.difference(service.rangeStart!);
      expect(dur.inSeconds, greaterThanOrEqualTo(1));
    });

    test('zoomBy with anchor zooms centered on anchor', () {
      service.updateSessionBounds(t0, t2);
      service.setRange(t0, t2);
      service.zoomBy(0.5, anchor: 0.0); // zoom from left edge
      // Left edge should stay near t0
      expect(service.rangeStart!.difference(t0).inSeconds.abs(), lessThan(2));
    });

    test('zoomBy is a no-op without session bounds', () {
      service.zoomBy(0.5);
      expect(service.state, TimeRangeState.full);
    });

    test('panBy shifts range right', () {
      service.updateSessionBounds(t0, t2);
      service.setRange(t0, t1); // 0..1 min
      final panDur = const Duration(seconds: 30);
      service.panBy(panDur);
      expect(service.rangeStart!.isAfter(t0), isTrue);
      // Range width preserved
      final dur = service.rangeEnd!.difference(service.rangeStart!);
      expect(dur.inSeconds, closeTo(60, 1));
    });

    test('panBy shifts range left', () {
      service.updateSessionBounds(t0, t2);
      service.setRange(t1, t2); // 1..2 min
      service.panBy(const Duration(seconds: -30));
      expect(service.rangeStart!.isBefore(t1), isTrue);
    });

    test('panBy clamps to session bounds', () {
      service.updateSessionBounds(t0, t2);
      service.setRange(t0, t1);
      service.panBy(const Duration(minutes: -5)); // try to go before session
      expect(service.rangeStart, t0);
    });

    test('panBy is a no-op when not active', () {
      service.updateSessionBounds(t0, t2);
      // FULL state — panBy should do nothing
      service.panBy(const Duration(seconds: 10));
      expect(service.state, TimeRangeState.full);
    });

    test('enterLiveTracking transitions from ZOOMED', () {
      service.updateSessionBounds(t0, t2);
      service.setRange(t0, t1);
      expect(service.state, TimeRangeState.zoomed);
      service.enterLiveTracking();
      expect(service.state, TimeRangeState.liveTracking);
      expect(service.rangeEnd, t2);
    });

    test('enterLiveTracking is a no-op from FULL', () {
      service.updateSessionBounds(t0, t2);
      service.enterLiveTracking();
      expect(service.state, TimeRangeState.full);
    });

    test('isInRange returns true when not active', () {
      expect(service.isInRange(t0), isTrue);
      expect(service.isInRange(t2), isTrue);
    });

    test('isInRange filters correctly when active', () {
      service.updateSessionBounds(t0, t2);
      service.setRange(t0, t1);
      expect(service.isInRange(t0), isTrue);
      expect(service.isInRange(t1), isTrue);
      final mid = t0.add(const Duration(seconds: 30));
      expect(service.isInRange(mid), isTrue);
      expect(service.isInRange(t2), isFalse);
    });

    test('maxBucketCount returns 0 when no buckets', () {
      expect(service.maxBucketCount, 0);
    });

    group('bucketing', () {
      test('updateBuckets creates buckets from entries', () {
        service.updateSessionBounds(t0, t2);
        final entries = [
          _entry(t0.toIso8601String()),
          _entry(t1.toIso8601String()),
          _entry(t2.toIso8601String()),
        ];
        service.updateBuckets(entries);
        expect(service.buckets.length, 3); // min(3, 120)
        expect(service.maxBucketCount, greaterThan(0));
      });

      test('updateBuckets handles empty entries', () {
        service.updateSessionBounds(t0, t2);
        service.updateBuckets([]);
        expect(service.buckets, isEmpty);
      });

      test('updateBuckets handles single entry', () {
        final ts = t0;
        service.updateSessionBounds(ts, ts);
        final entries = [_entry(ts.toIso8601String())];
        service.updateBuckets(entries);
        expect(service.buckets.length, 1);
        expect(service.buckets[0].totalCount, 1);
      });

      test('updateBuckets respects severity breakdown', () {
        service.updateSessionBounds(t0, t2);
        final entries = [
          _entry(t0.toIso8601String(), severity: Severity.error),
          _entry(t0.toIso8601String(), severity: Severity.info),
          _entry(t2.toIso8601String(), severity: Severity.debug),
        ];
        service.updateBuckets(entries);
        // First bucket should have error + info
        final first = service.buckets.first;
        expect(first.severityCounts[Severity.error], 1);
        expect(first.severityCounts[Severity.info], 1);
      });

      test('updateBuckets caps at 120 buckets', () {
        service.updateSessionBounds(t0, t2);
        final entries = List.generate(200, (i) {
          final ts = t0.add(Duration(seconds: i));
          return _entry(ts.toIso8601String());
        });
        service.updateBuckets(entries);
        expect(service.buckets.length, 120);
      });

      test('onNewEntry increments the correct bucket', () {
        service.updateSessionBounds(t0, t2);
        final entries = [
          _entry(t0.toIso8601String()),
          _entry(t2.toIso8601String()),
        ];
        service.updateBuckets(entries);
        final initialCount = service.buckets.first.totalCount;

        service.onNewEntry(_entry(t0.toIso8601String()));
        expect(service.buckets.first.totalCount, initialCount + 1);
      });

      test('onNewEntry extends sessionEnd', () {
        service.updateSessionBounds(t0, t1);
        service.updateBuckets([_entry(t0.toIso8601String())]);
        final newTs = t2;
        service.onNewEntry(_entry(newTs.toIso8601String()));
        expect(service.sessionEnd, newTs);
      });

      test('onNewEntry in LIVE_TRACKING extends rangeEnd', () {
        service.updateSessionBounds(t0, t1);
        service.updateBuckets([
          _entry(t0.toIso8601String()),
          _entry(t1.toIso8601String()),
        ]);
        service.setRange(t0, t1);
        service.enterLiveTracking();

        final newTs = t2;
        service.onNewEntry(_entry(newTs.toIso8601String()));
        expect(service.rangeEnd, newTs);
        expect(service.state, TimeRangeState.liveTracking);
      });
    });

    test('notifyListeners fires on setRange', () {
      service.updateSessionBounds(t0, t2);
      int count = 0;
      service.addListener(() => count++);
      service.setRange(t0, t1);
      expect(count, 1);
    });

    test('notifyListeners fires on resetRange', () {
      service.updateSessionBounds(t0, t2);
      service.setRange(t0, t1);
      int count = 0;
      service.addListener(() => count++);
      service.resetRange();
      expect(count, 1);
    });

    test('state machine: FULL → ZOOMED → LIVE → ZOOMED', () {
      service.updateSessionBounds(t0, t2);
      expect(service.state, TimeRangeState.full);

      // FULL → ZOOMED
      service.setRange(t0, t1);
      expect(service.state, TimeRangeState.zoomed);

      // ZOOMED → LIVE_TRACKING
      service.enterLiveTracking();
      expect(service.state, TimeRangeState.liveTracking);

      // LIVE_TRACKING → ZOOMED (via manual interaction)
      service.zoomBy(0.5);
      expect(service.state, TimeRangeState.zoomed);
    });

    test('state machine: LIVE_TRACKING → FULL via reset', () {
      service.updateSessionBounds(t0, t2);
      service.setRange(t0, t1);
      service.enterLiveTracking();
      expect(service.state, TimeRangeState.liveTracking);

      service.resetRange();
      expect(service.state, TimeRangeState.full);
    });
  });
}
