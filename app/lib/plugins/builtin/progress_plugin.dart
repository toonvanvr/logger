import 'package:flutter/material.dart';

import '../../models/log_entry.dart';
import '../../widgets/renderers/custom/progress_renderer.dart';
import '../plugin_manifest.dart';
import '../plugin_registry.dart';
import '../plugin_types.dart';

/// Built-in plugin wrapping the [ProgressRenderer] for `progress` custom type.
class ProgressRendererPlugin extends RendererPlugin with EnableablePlugin {
  @override
  String get id => 'dev.logger.progress-renderer';

  @override
  String get name => 'Progress Renderer';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Renders progress bars and ring indicators.';

  @override
  PluginManifest get manifest => const PluginManifest(
    id: 'dev.logger.progress-renderer',
    name: 'Progress Renderer',
    version: '1.0.0',
    description: 'Renders progress bars and ring indicators.',
    types: ['renderer'],
  );

  @override
  Set<String> get customTypes => const {'progress'};

  @override
  Widget buildRenderer(
    BuildContext context,
    Map<String, dynamic> data,
    LogEntry entry,
  ) {
    return ProgressRenderer(entry: entry);
  }

  @override
  void onRegister(PluginRegistry registry) {}

  @override
  void onDispose() {}
}
