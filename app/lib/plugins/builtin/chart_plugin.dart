import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/log_entry.dart';
import '../plugin_manifest.dart';
import '../plugin_registry.dart';
import '../plugin_types.dart';

/// Built-in renderer plugin for chart custom types.
///
/// Supports `bar`, `sparkline`, and `area` chart variants using
/// [CustomPainter] for efficient rendering.
class ChartRendererPlugin extends RendererPlugin with EnableablePlugin {
  // ─── Identity ──────────────────────────────────────────────────────

  @override
  String get id => 'dev.logger.chart-renderer';

  @override
  String get name => 'Chart Renderer';

  @override
  String get version => '1.0.0';

  @override
  String get description =>
      'Renders bar, sparkline, and area charts from log data.';

  @override
  PluginManifest get manifest => const PluginManifest(
    id: 'dev.logger.chart-renderer',
    name: 'Chart Renderer',
    version: '1.0.0',
    description: 'Renders bar, sparkline, and area charts from log data.',
    types: ['renderer'],
  );

  @override
  Set<String> get customTypes => const {'chart', 'sparkline', 'bar_chart'};

  // ─── Renderer ──────────────────────────────────────────────────────

  @override
  Widget buildRenderer(
    BuildContext context,
    Map<String, dynamic> data,
    LogEntry entry,
  ) {
    final variant = data['variant'] as String? ?? 'bar';
    final title = data['title'] as String?;

    // Support both flat value lists and {label, value} objects.
    final rawData = data['data'] as List?;
    final values = <num>[];
    final labels = <String>[];

    if (rawData != null) {
      for (final item in rawData) {
        if (item is Map) {
          values.add((item['value'] as num?) ?? 0);
          labels.add((item['label'] as String?) ?? '');
        } else if (item is num) {
          values.add(item);
        }
      }
    }

    // Fallback to flat "values" / "labels" arrays.
    if (values.isEmpty) {
      final flatValues = data['values'];
      if (flatValues is List) {
        for (final v in flatValues) {
          values.add((v as num?) ?? 0);
        }
      }
      final flatLabels = data['labels'];
      if (flatLabels is List) {
        for (final l in flatLabels) {
          labels.add(l.toString());
        }
      }
    }

    final theme = Theme.of(context);
    final chartColor = theme.colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              title,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
        CustomPaint(
          painter: ChartPainter(
            variant: variant,
            values: values,
            labels: labels.isNotEmpty ? labels : null,
            color: chartColor,
            textColor: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          size: const Size(double.infinity, 120),
        ),
      ],
    );
  }

  @override
  Widget? buildPreview(Map<String, dynamic> data) {
    final rawData = data['data'] as List?;
    final values = <num>[];
    if (rawData != null) {
      for (final item in rawData) {
        if (item is Map) {
          values.add((item['value'] as num?) ?? 0);
        } else if (item is num) {
          values.add(item);
        }
      }
    }
    if (values.isEmpty) return null;

    return CustomPaint(
      painter: ChartPainter(
        variant: 'sparkline',
        values: values,
        color: Colors.blueGrey,
        textColor: Colors.transparent,
      ),
      size: const Size(80, 24),
    );
  }

  // ─── Lifecycle ─────────────────────────────────────────────────────

  @override
  void onRegister(PluginRegistry registry) {}

  @override
  void onDispose() {}
}

// ─── Chart Painter ───────────────────────────────────────────────────

/// A [CustomPainter] that renders bar, sparkline, or area charts.
class ChartPainter extends CustomPainter {
  final String variant;
  final List<num> values;
  final List<String>? labels;
  final Color color;
  final Color textColor;

  const ChartPainter({
    required this.variant,
    required this.values,
    this.labels,
    required this.color,
    required this.textColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    switch (variant) {
      case 'sparkline':
        _paintSparkline(canvas, size);
      case 'area':
        _paintArea(canvas, size);
      default:
        _paintBar(canvas, size);
    }
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

      // Draw label below bar.
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

    // Fill area.
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

    // Stroke line.
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

  @override
  bool shouldRepaint(ChartPainter oldDelegate) {
    return variant != oldDelegate.variant ||
        values != oldDelegate.values ||
        color != oldDelegate.color;
  }
}
