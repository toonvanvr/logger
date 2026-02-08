import 'package:flutter/material.dart';

import '../../models/log_entry.dart';
import '../../widgets/renderers/custom/http_request_renderer.dart';
import '../plugin_manifest.dart';
import '../plugin_registry.dart';
import '../plugin_types.dart';

/// Built-in plugin wrapping the [HttpRequestRenderer] for `http_request`
/// custom type.
class HttpRequestRendererPlugin extends RendererPlugin with EnableablePlugin {
  @override
  String get id => 'dev.logger.http-request-renderer';

  @override
  String get name => 'HTTP Request Renderer';

  @override
  String get version => '1.0.0';

  @override
  String get description =>
      'Renders HTTP request/response entries with status, headers, and body.';

  @override
  PluginManifest get manifest => const PluginManifest(
    id: 'dev.logger.http-request-renderer',
    name: 'HTTP Request Renderer',
    version: '1.0.0',
    description:
        'Renders HTTP request/response entries with status, headers, and body.',
    types: ['renderer'],
  );

  @override
  Set<String> get customTypes => const {'http_request'};

  @override
  Widget buildRenderer(
    BuildContext context,
    Map<String, dynamic> data,
    LogEntry entry,
  ) {
    return HttpRequestRenderer(entry: entry);
  }

  @override
  void onRegister(PluginRegistry registry) {}

  @override
  void onDispose() {}
}
