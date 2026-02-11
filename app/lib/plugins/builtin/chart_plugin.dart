import 'package:flutter/material.dart';

import '../../models/log_entry.dart';
import '../../theme/colors.dart';
import '../plugin_manifest.dart';
import '../plugin_registry.dart';
import '../plugin_types.dart';
import 'chart_painter.dart';

export 'chart_painter.dart';

class ChartRendererPlugin extends RendererPlugin with EnableablePlugin {
  /// Chart render height. Defaults to 120.
  final double height;

  ChartRendererPlugin({this.height = 120});

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
  @override
  Widget buildRenderer(
    BuildContext context,
    Map<String, dynamic> data,
    LogEntry entry,
  ) {
    final variant =
        data['variant'] as String? ?? data['type'] as String? ?? 'bar';
    final title = data['title'] as String?;
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
          size: Size(double.infinity, height),
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
        color: LoggerColors.fgSecondary,
        textColor: Colors.transparent,
      ),
      size: const Size(80, 24),
    );
  }

  @override
  void onRegister(PluginRegistry registry) {}
  @override
  void onDispose() {}
}
