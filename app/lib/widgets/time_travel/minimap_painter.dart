import 'package:flutter/material.dart';

import '../../models/log_entry.dart';
import '../../services/time_range_types.dart';
import '../../theme/colors.dart';

/// Custom painter for the minimap bars, viewport, and handles.
@visibleForTesting
class MinimapPainter extends CustomPainter {
  final List<BucketData> buckets;
  final int maxCount;
  final double vpStart;
  final double vpEnd;
  final bool isActive;
  final bool leftHandleHovered;
  final bool rightHandleHovered;

  static const double _barAreaTop = 8.0;
  static const double _barAreaHeight = 24.0;
  static const double _hPadding = 8.0;
  static const double _handleWidth = 3.0;
  static const double _handleHoverWidth = 5.0;

  /// Severity rendering order (bottom to top).
  static const _severityOrder = [
    Severity.debug,
    Severity.info,
    Severity.warning,
    Severity.error,
    Severity.critical,
  ];

  static const _severityColors = {
    Severity.debug: LoggerColors.severityDebugBar,
    Severity.info: LoggerColors.severityInfoBar,
    Severity.warning: LoggerColors.severityWarningBar,
    Severity.error: LoggerColors.severityErrorBar,
    Severity.critical: LoggerColors.severityCriticalBar,
  };

  MinimapPainter({
    required this.buckets,
    required this.maxCount,
    required this.vpStart,
    required this.vpEnd,
    required this.isActive,
    this.leftHandleHovered = false,
    this.rightHandleHovered = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (buckets.isEmpty || maxCount == 0) return;

    final barAreaWidth = size.width - 2 * _hPadding;
    if (barAreaWidth <= 0) return;

    final barWidth = barAreaWidth / buckets.length;

    for (int i = 0; i < buckets.length; i++) {
      final bucket = buckets[i];
      if (bucket.totalCount == 0) continue;

      final x = _hPadding + i * barWidth;
      final totalHeight = (bucket.totalCount / maxCount) * _barAreaHeight;

      double yBottom = _barAreaTop + _barAreaHeight;
      for (final severity in _severityOrder) {
        final count = bucket.severityCounts[severity] ?? 0;
        if (count == 0) continue;
        final segH = (count / bucket.totalCount) * totalHeight;
        final rect = Rect.fromLTWH(x, yBottom - segH, barWidth, segH);
        canvas.drawRect(rect, Paint()..color = _severityColors[severity]!);
        yBottom -= segH;
      }
    }

    if (isActive) {
      final vpLeftX = _hPadding + vpStart * barAreaWidth;
      final vpRightX = _hPadding + vpEnd * barAreaWidth;

      final dimPaint = Paint()
        ..color = LoggerColors.bgBase.withValues(alpha: 0.5);

      canvas.drawRect(
        Rect.fromLTWH(
          _hPadding,
          _barAreaTop,
          vpLeftX - _hPadding,
          _barAreaHeight,
        ),
        dimPaint,
      );
      canvas.drawRect(
        Rect.fromLTWH(
          vpRightX,
          _barAreaTop,
          size.width - _hPadding - vpRightX,
          _barAreaHeight,
        ),
        dimPaint,
      );

      canvas.drawRect(
        Rect.fromLTWH(vpLeftX, _barAreaTop, vpRightX - vpLeftX, _barAreaHeight),
        Paint()..color = LoggerColors.bgActive.withValues(alpha: 0.4),
      );

      final borderPaint = Paint()
        ..color = LoggerColors.borderFocus
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawRect(
        Rect.fromLTWH(vpLeftX, _barAreaTop, vpRightX - vpLeftX, _barAreaHeight),
        borderPaint,
      );

      final lhWidth = leftHandleHovered ? _handleHoverWidth : _handleWidth;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            vpLeftX - lhWidth / 2,
            _barAreaTop,
            lhWidth,
            _barAreaHeight,
          ),
          const Radius.circular(1.5),
        ),
        Paint()..color = LoggerColors.borderFocus,
      );

      final rhWidth = rightHandleHovered ? _handleHoverWidth : _handleWidth;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            vpRightX - rhWidth / 2,
            _barAreaTop,
            rhWidth,
            _barAreaHeight,
          ),
          const Radius.circular(1.5),
        ),
        Paint()..color = LoggerColors.borderFocus,
      );
    }
  }

  @override
  bool shouldRepaint(covariant MinimapPainter old) =>
      old.maxCount != maxCount ||
      old.vpStart != vpStart ||
      old.vpEnd != vpEnd ||
      old.isActive != isActive ||
      old.leftHandleHovered != leftHandleHovered ||
      old.rightHandleHovered != rightHandleHovered ||
      !_bucketsEqual(old.buckets, buckets);

  bool _bucketsEqual(List<BucketData> a, List<BucketData> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].totalCount != b[i].totalCount) return false;
    }
    return true;
  }
}
