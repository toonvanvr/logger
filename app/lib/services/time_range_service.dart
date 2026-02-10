import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../models/log_entry.dart';
import 'time_range_types.dart';

export 'time_range_types.dart';

part 'time_range_model.dart';

/// Manages time range state for the minimap and log filtering.
/// States: FULL (entire session), ZOOMED (sub-range), LIVE_TRACKING.
class TimeRangeService extends ChangeNotifier {
  DateTime? _sessionStart;
  DateTime? _sessionEnd;
  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  TimeRangeState _state = TimeRangeState.full;
  List<BucketData> _buckets = [];
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

  /// Resets to full range (FULL state).
  void resetRange() {
    _rangeStart = null;
    _rangeEnd = null;
    _state = TimeRangeState.full;
    notifyListeners();
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
}
