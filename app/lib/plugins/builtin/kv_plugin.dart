import 'package:flutter/material.dart';

import '../../models/log_entry.dart';
import '../../widgets/renderers/custom/kv_renderer.dart';
import '../plugin_manifest.dart';
import '../plugin_registry.dart';
import '../plugin_types.dart';

/// Built-in plugin wrapping the [KvRenderer] for `kv` custom type.
class KvRendererPlugin extends RendererPlugin with EnableablePlugin {
  @override
  String get id => 'dev.logger.kv-renderer';

  @override
  String get name => 'Key-Value Renderer';

  @override
  String get version => '1.0.0';

  @override
  String get description =>
      'Renders key-value pairs in inline or stacked layout.';

  @override
  PluginManifest get manifest => const PluginManifest(
    id: 'dev.logger.kv-renderer',
    name: 'Key-Value Renderer',
    version: '1.0.0',
    description: 'Renders key-value pairs in inline or stacked layout.',
    types: ['renderer'],
  );

  @override
  Set<String> get customTypes => const {'kv'};

  @override
  Widget buildRenderer(
    BuildContext context,
    Map<String, dynamic> data,
    LogEntry entry,
  ) {
    return KvRenderer(entry: entry);
  }

  @override
  void onRegister(PluginRegistry registry) {}

  @override
  void onDispose() {}
}
