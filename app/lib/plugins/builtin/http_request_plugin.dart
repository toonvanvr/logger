import 'package:flutter/material.dart';

import '../../models/log_entry.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';
import '../../widgets/renderers/custom/http/http_utils.dart';
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
  Widget? buildPreview(Map<String, dynamic> data) {
    final method = data['method'] as String?;
    final url = data['url'] as String?;
    if (method == null || url == null) return null;

    final status = (data['status'] as num?)?.toInt();
    final durationMs = (data['duration_ms'] as num?)?.toInt();
    final isError = data['is_error'] == true;
    final statusText = data['status_text'] as String?;
    final parsed = parseUrl(url);
    final (sColor, sLabel) = classifyStatus(
      status,
      isError,
      statusText: statusText,
    );
    final dColor = durationColor(durationMs);
    final mColor = methodColor(method);
    final durText = durationMs != null ? ' ${durationMs}ms' : '';

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '[$method] ',
            style: LoggerTypography.logMeta.copyWith(
              color: mColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          TextSpan(
            text: parsed.path,
            style: LoggerTypography.logMeta.copyWith(
              color: LoggerColors.fgPrimary,
            ),
          ),
          TextSpan(
            text: ' → ',
            style: LoggerTypography.logMeta.copyWith(
              color: LoggerColors.fgMuted,
            ),
          ),
          TextSpan(
            text: sLabel,
            style: LoggerTypography.logMeta.copyWith(
              color: sColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          TextSpan(
            text: durText,
            style: LoggerTypography.logMeta.copyWith(color: dColor),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  @override
  void onRegister(PluginRegistry registry) {}

  @override
  void onDispose() {}
}
