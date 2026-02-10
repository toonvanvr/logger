import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../models/log_entry.dart';
import 'time_range_types.dart';

export 'time_range_types.dart';

/// Manages time range state for the minimap and log filtering.
/// States: FULL (entire session), ZOOMED (sub-range), LIVE_TRACKING.
class TimeRangeService extends ChangeNotifier {
  DateTime? _sessionStart;
  DateTime? _sessionEnd;
  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  TimeRangeState _state = TimeRangeState.full;
  List<BucketData> _buckets = [];

  /// Minimum allowed range width.
  static const _minRange = Duration(seconds: 1);

  bool _dirty = false;

  /// Batches multiple mutations in the same frame into a single notification.
  void _scheduleNotify() {
    if (!_dirty) {
      _dirty = true;
      Future.microtask(() {
        _dirty = false;
        notifyListeners();
      });
    }
  }

  DateTime? get sessionStart => _sessionStart;
  DateTime? get sessionEnd => _sessionEnd;
  DateTime? get rangeStart => _rangeStart ?? _sessionStart;
  DateTime? get rangeEnd => _rangeEnd ?? _sessionEnd;
  TimeRangeState get state => _state;
  List<BucketData> get buckets => _buckets;

  bool get isActive =>
      _state == TimeRangeState.zoomed || _state == TimeRangeState.liveTracking;

  /// Normalized viewport start position (0..1).
  double get viewportStartNorm {
    if (_sessionStart == null || _sessionEnd == null) return 0.0;
    final total = _sessionEnd!.difference(_sessionStart!).inMicroseconds;
    if (total <= 0) return 0.0;
    final start = (rangeStart!).difference(_sessionStart!).inMicroseconds;
    return (start / total).clamp(0.0, 1.0);
  }

  /// Normalized viewport end position (0..1).
  double get viewportEndNorm {
    if (_sessionStart == null || _sessionEnd == null) return 1.0;
    final total = _sessionEnd!.difference(_sessionStart!).inMicroseconds;
    if (total <= 0) return 1.0;
    final end = (rangeEnd!).difference(_sessionStart!).inMicroseconds;
    return (end / total).clamp(0.0, 1.0);
  }

  /// Maximum bucket count across all buckets (for bar height scaling).
  int get maxBucketCount {
    if (_buckets.isEmpty) return 0;
    return _buckets.fold(0, (m, b) => math.max(m, b.totalCount));
  }

  void updateSessionBounds(DateTime start, DateTime end) {
    _sessionStart = start;
    _sessionEnd = end;
    _scheduleNotify();
  }

  /// Sets a custom time range, transitioning to ZOOMED state.
  void setRange(DateTime start, DateTime end) {
    if (_sessionStart == null || _sessionEnd == null) return;

    // Auto-swap if inverted.
    if (start.isAfter(end)) {
      final tmp = start;
      start = end;
      end = tmp;
    }

    // Clamp to session bounds.
    start = _clampToSession(start);
    end = _clampToSession(end);

    // Enforce minimum range.
    if (end.difference(start) < _minRange) {
      end = start.add(_minRange);
      if (end.isAfter(_sessionEnd!)) {
        end = _sessionEnd!;
        start = end.subtract(_minRange);
        if (start.isBefore(_sessionStart!)) {
          start = _sessionStart!;
        }
      }
    }

    _rangeStart = start;
    _rangeEnd = end;
    _state = TimeRangeState.zoomed;
    _scheduleNotify();
  }

  /// Resets to full range (FULL state).
  void resetRange() {
    _rangeStart = null;
    _rangeEnd = null;
    _state = TimeRangeState.full;
    notifyListeners();
  }

  /// Zoom in/out. factor < 1 = zoom in, factor > 1 = zoom out.
  void zoomBy(double factor, {double? anchor}) {
    if (_sessionStart == null || _sessionEnd == null) return;
    factor = factor.clamp(0.01, 100.0);

    final sessionDur = _sessionEnd!.difference(_sessionStart!);
    if (sessionDur <= Duration.zero) return;

    final currentStart = rangeStart!;
    final currentEnd = rangeEnd!;
    final currentDur = currentEnd.difference(currentStart);

    final newDurUs = (currentDur.inMicroseconds * factor).round();
    final newDur = Duration(microseconds: newDurUs);

    // If zooming out past full range, reset.
    if (newDur >= sessionDur) {
      resetRange();
      return;
    }

    // Enforce minimum range.
    if (newDur < _minRange) return;

    final anchorNorm = anchor ?? 0.5;
    final anchorUs =
        currentStart.microsecondsSinceEpoch +
        (currentDur.inMicroseconds * anchorNorm).round();

    final newStartUs = anchorUs - (newDur.inMicroseconds * anchorNorm).round();
    var newStart = DateTime.fromMicrosecondsSinceEpoch(newStartUs, isUtc: true);
    var newEnd = newStart.add(newDur);

    // Clamp to session.
    if (newStart.isBefore(_sessionStart!)) {
      newStart = _sessionStart!;
      newEnd = newStart.add(newDur);
    }
    if (newEnd.isAfter(_sessionEnd!)) {
      newEnd = _sessionEnd!;
      newStart = newEnd.subtract(newDur);
      if (newStart.isBefore(_sessionStart!)) {
        newStart = _sessionStart!;
      }
    }

    _rangeStart = newStart;
    _rangeEnd = newEnd;
    _state = TimeRangeState.zoomed;
    _scheduleNotify();
  }

  /// Pan (shift) range by a duration offset. Positive = right, negative = left.
  void panBy(Duration offset) {
    if (_sessionStart == null || _sessionEnd == null || !isActive) return;

    final currentStart = rangeStart!;
    final currentEnd = rangeEnd!;
    final rangeDur = currentEnd.difference(currentStart);

    var newStart = currentStart.add(offset);
    var newEnd = currentEnd.add(offset);

    // Clamp to session bounds, preserving range width.
    if (newStart.isBefore(_sessionStart!)) {
      newStart = _sessionStart!;
      newEnd = newStart.add(rangeDur);
    }
    if (newEnd.isAfter(_sessionEnd!)) {
      newEnd = _sessionEnd!;
      newStart = newEnd.subtract(rangeDur);
      if (newStart.isBefore(_sessionStart!)) {
        newStart = _sessionStart!;
      }
    }

    _rangeStart = newStart;
    _rangeEnd = newEnd;
    _scheduleNotify();
  }

  /// Enter live tracking mode (right edge follows sessionEnd).
  void enterLiveTracking() {
    if (!isActive) return;
    _state = TimeRangeState.liveTracking;
    _rangeEnd = _sessionEnd;
    _scheduleNotify();
  }

  /// Check if a timestamp falls within the current range.
  bool isInRange(DateTime ts) {
    if (!isActive) return true;
    final start = rangeStart;
    final end = rangeEnd;
    if (start == null || end == null) return true;
    return !ts.isBefore(start) && !ts.isAfter(end);
  }

  /// Full recompute of buckets from a list of entries.
  void updateBuckets(List<LogEntry> entries) {
    if (_sessionStart == null || _sessionEnd == null || entries.isEmpty) {
      _buckets = [];
      _scheduleNotify();
      return;
    }

    final sessionDur = _sessionEnd!.difference(_sessionStart!);
    if (sessionDur <= Duration.zero) {
      _buckets = [
        BucketData(bucketStart: _sessionStart!, bucketEnd: _sessionEnd!),
      ];
      // Count entries in the single bucket.
      for (final entry in entries) {
        _buckets[0].increment(entry.severity);
      }
      _scheduleNotify();
      return;
    }

    final bucketCount = entries.length.clamp(1, 120);
    final bucketWidthUs = sessionDur.inMicroseconds ~/ bucketCount;

    _buckets = List.generate(bucketCount, (i) {
      final start = _sessionStart!.add(
        Duration(microseconds: bucketWidthUs * i),
      );
      final end = i == bucketCount - 1
          ? _sessionEnd!
          : _sessionStart!.add(Duration(microseconds: bucketWidthUs * (i + 1)));
      return BucketData(bucketStart: start, bucketEnd: end);
    });

    for (final entry in entries) {
      final ts = DateTime.parse(entry.timestamp);
      final offsetUs = ts.difference(_sessionStart!).inMicroseconds;
      final idx = bucketWidthUs > 0
          ? (offsetUs ~/ bucketWidthUs).clamp(0, bucketCount - 1)
          : 0;
      _buckets[idx].increment(entry.severity);
    }

    _scheduleNotify();
  }

  /// Incremental update: add a single entry to the appropriate bucket.
  void onNewEntry(LogEntry entry) {
    final ts = DateTime.parse(entry.timestamp);

    // Extend session bounds if needed.
    if (_sessionStart == null || ts.isBefore(_sessionStart!)) {
      _sessionStart = ts;
    }
    if (_sessionEnd == null || ts.isAfter(_sessionEnd!)) {
      _sessionEnd = ts;
      // In live tracking mode, extend range end.
      if (_state == TimeRangeState.liveTracking) {
        _rangeEnd = _sessionEnd;
      }
    }

    // If no buckets yet, nothing to increment.
    if (_buckets.isEmpty) return;

    // Find bucket index.
    final sessionDur = _sessionEnd!.difference(_sessionStart!);
    if (sessionDur <= Duration.zero) {
      _buckets[0].increment(entry.severity);
      _scheduleNotify();
      return;
    }

    final bucketWidthUs = sessionDur.inMicroseconds ~/ _buckets.length;
    if (bucketWidthUs <= 0) {
      _buckets.last.increment(entry.severity);
      _scheduleNotify();
      return;
    }

    final offsetUs = ts.difference(_sessionStart!).inMicroseconds;
    final idx = (offsetUs ~/ bucketWidthUs).clamp(0, _buckets.length - 1);
    _buckets[idx].increment(entry.severity);
    _scheduleNotify();
  }

  DateTime _clampToSession(DateTime dt) {
    if (dt.isBefore(_sessionStart!)) return _sessionStart!;
    if (dt.isAfter(_sessionEnd!)) return _sessionEnd!;
    return dt;
  }
}
