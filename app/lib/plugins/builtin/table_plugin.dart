import 'package:flutter/material.dart';

import '../../models/log_entry.dart';
import '../../widgets/renderers/custom/table_renderer.dart';
import '../plugin_manifest.dart';
import '../plugin_registry.dart';
import '../plugin_types.dart';

/// Built-in plugin wrapping the [TableRenderer] for `table` custom type.
class TableRendererPlugin extends RendererPlugin with EnableablePlugin {
  @override
  String get id => 'dev.logger.table-renderer';

  @override
  String get name => 'Table Renderer';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Renders tabular data with headers and rows.';

  @override
  PluginManifest get manifest => const PluginManifest(
    id: 'dev.logger.table-renderer',
    name: 'Table Renderer',
    version: '1.0.0',
    description: 'Renders tabular data with headers and rows.',
    types: ['renderer'],
  );

  @override
  Set<String> get customTypes => const {'table'};

  @override
  Widget buildRenderer(
    BuildContext context,
    Map<String, dynamic> data,
    LogEntry entry,
  ) {
    return TableRenderer(entry: entry);
  }

  @override
  void onRegister(PluginRegistry registry) {}

  @override
  void onDispose() {}
}
