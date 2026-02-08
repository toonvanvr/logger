import 'package:flutter/material.dart';

import '../../plugins/builtin/chart_painter.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';

/// Horizontal scrollable strip of live-updating charts from `_chart.*` state keys.
class StateChartStrip extends StatelessWidget {
  final Map<String, dynamic> chartEntries;

  const StateChartStrip({super.key, required this.chartEntries});

  @override
  Widget build(BuildContext context) {
    if (chartEntries.isEmpty) return const SizedBox.shrink();

    final entries = chartEntries.entries.toList();

    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final entry = entries[index];
          final data = _parseChartData(entry.value);
          if (data == null) return const SizedBox.shrink();

          return Container(
            width: 160,
            height: 72,
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
            decoration: BoxDecoration(
              color: LoggerColors.bgSurface,
              border: Border.all(color: LoggerColors.borderSubtle),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (data.title != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      data.title!,
                      style: LoggerTypography.logMeta.copyWith(
                        color: LoggerColors.fgSecondary,
                        fontSize: 9,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                Expanded(
                  child: CustomPaint(
                    painter: ChartPainter(
                      variant: data.type,
                      values: data.values,
                      color: data.color ?? LoggerColors.syntaxKey,
                      textColor: LoggerColors.fgMuted,
                      showTicks: true,
                    ),
                    size: Size.infinite,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  _ChartData? _parseChartData(dynamic value) {
    if (value is! Map) return null;
    final map = value is Map<String, dynamic>
        ? value
        : Map<String, dynamic>.from(value);

    final type = map['type'] as String? ?? 'bar';
    final rawValues = map['values'];
    if (rawValues is! List || rawValues.length < 2) return null;

    final values = rawValues.whereType<num>().toList();
    if (values.length < 2) return null;

    final title = map['title'] as String?;
    final colorStr = map['color'] as String?;
    Color? color;
    if (colorStr != null && colorStr.startsWith('#') && colorStr.length == 7) {
      color = Color(int.parse('FF${colorStr.substring(1)}', radix: 16));
    }

    return _ChartData(type: type, values: values, title: title, color: color);
  }
}

class _ChartData {
  final String type;
  final List<num> values;
  final String? title;
  final Color? color;

  const _ChartData({
    required this.type,
    required this.values,
    this.title,
    this.color,
  });
}
