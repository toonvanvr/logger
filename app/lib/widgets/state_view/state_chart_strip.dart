import 'package:flutter/material.dart';

import '../../plugins/builtin/chart_painter.dart';
import '../../theme/colors.dart';
import '../../theme/constants.dart';
import '../../theme/typography.dart';

/// Horizontal scrollable strip of live-updating charts from `_chart.*` state keys.
class StateChartStrip extends StatelessWidget {
  final Map<String, dynamic> chartEntries;
  final ValueChanged<String>? onTap;

  /// Height of the strip container. Defaults to 80.
  final double stripHeight;

  /// Width of each chart card. Defaults to 160.
  final double cardWidth;

  /// Height of each chart card. Defaults to 72.
  final double cardHeight;

  const StateChartStrip({
    super.key,
    required this.chartEntries,
    this.onTap,
    this.stripHeight = 80,
    this.cardWidth = 160,
    this.cardHeight = 72,
  });

  @override
  Widget build(BuildContext context) {
    if (chartEntries.isEmpty) return const SizedBox.shrink();

    final entries = chartEntries.entries.toList();

    return SizedBox(
      height: stripHeight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: kHPadding8,
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final entry = entries[index];
          final data = _parseChartData(entry.value);
          if (data == null) return const SizedBox.shrink();

          return _ChartCard(
            data: data,
            cardWidth: cardWidth,
            cardHeight: cardHeight,
            onTap: onTap != null ? () => onTap!(data.title ?? entry.key) : null,
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

class _ChartCard extends StatefulWidget {
  final _ChartData data;
  final VoidCallback? onTap;
  final double cardWidth;
  final double cardHeight;

  const _ChartCard({
    required this.data,
    this.onTap,
    this.cardWidth = 160,
    this.cardHeight = 72,
  });

  @override
  State<_ChartCard> createState() => _ChartCardState();
}

class _ChartCardState extends State<_ChartCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: MouseRegion(
        cursor: widget.onTap != null
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Container(
          width: widget.cardWidth,
          height: widget.cardHeight,
          margin: const EdgeInsets.only(right: 6),
          padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
          decoration: BoxDecoration(
            color: LoggerColors.bgSurface,
            border: Border.all(
              color: Color.lerp(
                LoggerColors.borderSubtle,
                Colors.white,
                _isHovered ? 0.1 : 0.0,
              )!,
            ),
            borderRadius: kBorderRadiusSm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.data.title != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    widget.data.title!,
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
                    variant: widget.data.type,
                    values: widget.data.values,
                    color: widget.data.color ?? LoggerColors.syntaxKey,
                    textColor: LoggerColors.fgMuted,
                    showTicks: true,
                  ),
                  size: Size.infinite,
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
