part of 'time_range_service.dart';

/// Minimum allowed range width.
const Duration _minRange = Duration(seconds: 1);

/// Range manipulation operations on [TimeRangeService].
extension TimeRangeOps on TimeRangeService {
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

  DateTime _clampToSession(DateTime dt) {
    if (dt.isBefore(_sessionStart!)) return _sessionStart!;
    if (dt.isAfter(_sessionEnd!)) return _sessionEnd!;
    return dt;
  }
}
