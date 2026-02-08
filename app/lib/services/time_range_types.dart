import '../models/log_entry.dart';

/// State machine states for the time range feature.
enum TimeRangeState { full, zoomed, liveTracking }

/// Bucketed log density data for minimap rendering.
class BucketData {
  int totalCount;
  final Map<Severity, int> severityCounts;
  final DateTime bucketStart;
  final DateTime bucketEnd;

  BucketData({
    this.totalCount = 0,
    Map<Severity, int>? severityCounts,
    required this.bucketStart,
    required this.bucketEnd,
  }) : severityCounts = severityCounts ?? {};

  void increment(Severity severity) {
    totalCount++;
    severityCounts[severity] = (severityCounts[severity] ?? 0) + 1;
  }
}
