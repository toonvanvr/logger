import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Custom painter for bar, sparkline, area, and dense bar charts.
class ChartPainter extends CustomPainter {
  final String variant;
  final List<num> values;
  final List<String>? labels;
  final Color color;
  final Color textColor;
  final bool showTicks;
  final Color? tickColor;
  const ChartPainter({
    required this.variant,
    required this.values,
    this.labels,
    required this.color,
    required this.textColor,
    this.showTicks = false,
    this.tickColor,
  });
  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    switch (variant) {
      case 'sparkline':
        _paintSparkline(canvas, size);
      case 'area':
        _paintArea(canvas, size);
      case 'dense_bar':
        _paintDenseBar(canvas, size);
      default:
        _paintBar(canvas, size);
    }
    if (showTicks) _paintTicks(canvas, size);
  }

  void _paintBar(Canvas canvas, Size size) {
    final maxVal = values.reduce(math.max).toDouble();
    if (maxVal == 0) return;
    final barCount = values.length;
    final gap = 4.0;
    final labelHeight = labels != null ? 16.0 : 0.0;
    final chartHeight = size.height - labelHeight;
    final barWidth = (size.width - gap * (barCount - 1)) / barCount;
    final paint = Paint()..color = color;
    for (var i = 0; i < barCount; i++) {
      final x = i * (barWidth + gap);
      final barHeight = (values[i] / maxVal) * chartHeight;
      final rect = Rect.fromLTWH(
        x,
        chartHeight - barHeight,
        barWidth,
        barHeight,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        paint,
      );
      if (labels != null && i < labels!.length) {
        final span = TextSpan(
          text: labels![i],
          style: TextStyle(color: textColor, fontSize: 9),
        );
        final tp = TextPainter(
          text: span,
          textDirection: TextDirection.ltr,
          maxLines: 1,
          ellipsis: '…',
        )..layout(maxWidth: barWidth);
        tp.paint(canvas, Offset(x, chartHeight + 2));
      }
    }
  }

  void _paintSparkline(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final maxVal = values.reduce(math.max).toDouble();
    final minVal = values.reduce(math.min).toDouble();
    final range = maxVal - minVal;
    if (range == 0) return;
    final step = size.width / (values.length - 1);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = i * step;
      final y = size.height - ((values[i] - minVal) / range) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  void _paintArea(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final maxVal = values.reduce(math.max).toDouble();
    final minVal = values.reduce(math.min).toDouble();
    final range = maxVal - minVal;
    if (range == 0) return;
    final step = size.width / (values.length - 1);
    final fillPath = Path();
    fillPath.moveTo(0, size.height);
    for (var i = 0; i < values.length; i++) {
      final x = i * step;
      final y = size.height - ((values[i] - minVal) / range) * size.height;
      fillPath.lineTo(x, y);
    }
    fillPath.lineTo(size.width, size.height);
    fillPath.close();
    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);
    final linePath = Path();
    for (var i = 0; i < values.length; i++) {
      final x = i * step;
      final y = size.height - ((values[i] - minVal) / range) * size.height;
      if (i == 0) {
        linePath.moveTo(x, y);
      } else {
        linePath.lineTo(x, y);
      }
    }
    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(linePath, linePaint);
  }

  void _paintDenseBar(Canvas canvas, Size size) {
    final maxVal = values.reduce(math.max).toDouble();
    if (maxVal == 0) return;
    final barCount = values.length;
    const gap = 1.0;
    final barWidth = math.max(
      2.0,
      (size.width - gap * (barCount - 1)) / barCount,
    );
    final paint = Paint()..color = color;
    for (var i = 0; i < barCount; i++) {
      final x = i * (barWidth + gap);
      if (x > size.width) break;
      final barHeight = (values[i] / maxVal) * size.height;
      final rect = Rect.fromLTWH(
        x,
        size.height - barHeight,
        barWidth,
        barHeight,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(1)),
        paint,
      );
    }
  }

  void _paintTicks(Canvas canvas, Size size) {
    final effectiveColor = tickColor ?? textColor.withValues(alpha: 0.4);
    final paint = Paint()
      ..color = effectiveColor
      ..strokeWidth = 1;
    final yCount = size.height < 48 ? 2 : 3;
    for (var i = 0; i < yCount; i++) {
      final y = i == 0
          ? 0.0
          : (i == yCount - 1 ? size.height : size.height / 2);
      canvas.drawLine(Offset(-3, y), Offset(0, y), paint);
    }
    if (labels != null && size.width > 120) {
      final xCount = math.min(5, labels!.length);
      if (xCount > 0) {
        final step = size.width / xCount;
        for (var i = 0; i < xCount; i++) {
          final x = i * step + step / 2;
          canvas.drawLine(
            Offset(x, size.height),
            Offset(x, size.height + 3),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(ChartPainter oldDelegate) {
    return variant != oldDelegate.variant ||
        values != oldDelegate.values ||
        color != oldDelegate.color ||
        showTicks != oldDelegate.showTicks ||
        tickColor != oldDelegate.tickColor;
  }
}
