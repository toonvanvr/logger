import 'package:flutter/material.dart';

import '../../models/status_bar_item.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';
import '../plugin_manifest.dart';
import '../plugin_registry.dart';
import '../plugin_types.dart';

/// Tool plugin for Docker container log integration.
///
/// Provides viewer-side configuration and activation for the Docker
/// sidecar log streaming. When enabled, signals settings to include
/// Docker log streaming config via the existing server connection.
class DockerLogsPlugin extends ToolPlugin with EnableablePlugin {
  String _socketPath = '/var/run/docker.sock';
  String _containerFilter = '';
  bool _autoStart = false;

  // ─── Identity ──────────────────────────────────────────────────────

  @override
  String get id => 'dev.logger.docker-logs';

  @override
  String get name => 'Docker Container Logs';

  @override
  String get version => '1.0.0';

  @override
  String get description =>
      'Stream container logs from a Docker daemon into the viewer.';

  @override
  PluginManifest get manifest => const PluginManifest(
    id: 'dev.logger.docker-logs',
    name: 'Docker Container Logs',
    version: '1.0.0',
    description: 'Stream container logs from a Docker daemon into the viewer.',
    types: ['tool'],
    group: ToolGroups.connections,
    hasConfigPanel: true,
    disableable: true,
  );

  // ─── Tool ──────────────────────────────────────────────────────────

  @override
  String get toolLabel => 'Docker Logs';

  @override
  IconData get toolIcon => Icons.directions_boat;

  @override
  void onRegister(PluginRegistry registry) {}

  @override
  void onDispose() {}

  // ─── Panels ────────────────────────────────────────────────────────

  @override
  Widget buildToolPanel(BuildContext context) {
    return _DockerLogsPanel(
      enabled: enabled,
      socketPath: _socketPath,
      containerFilter: _containerFilter,
      autoStart: _autoStart,
      onEnabledChanged: (v) => setEnabled(v),
      onSocketPathChanged: (v) => _socketPath = v,
      onContainerFilterChanged: (v) => _containerFilter = v,
      onAutoStartChanged: (v) => _autoStart = v,
    );
  }

  @override
  Widget buildConfigPanel(BuildContext context) => buildToolPanel(context);

  // ─── Status bar ────────────────────────────────────────────────────

  @override
  List<StatusBarItem> get statusBarItems {
    if (!enabled) return const [];
    return [
      StatusBarItem(
        id: 'docker-logs-status',
        label: 'Docker: active',
        icon: Icons.directions_boat,
        priority: 80,
      ),
    ];
  }
}

// ─── Config panel ────────────────────────────────────────────────────

class _DockerLogsPanel extends StatelessWidget {
  final bool enabled;
  final String socketPath;
  final String containerFilter;
  final bool autoStart;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<String> onSocketPathChanged;
  final ValueChanged<String> onContainerFilterChanged;
  final ValueChanged<bool> onAutoStartChanged;

  const _DockerLogsPanel({
    required this.enabled,
    required this.socketPath,
    required this.containerFilter,
    required this.autoStart,
    required this.onEnabledChanged,
    required this.onSocketPathChanged,
    required this.onContainerFilterChanged,
    required this.onAutoStartChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SwitchListTile(
          dense: true,
          title: Text(
            'Enable Docker Logs',
            style: LoggerTypography.logMeta.copyWith(
              color: LoggerColors.fgPrimary,
            ),
          ),
          value: enabled,
          onChanged: onEnabledChanged,
        ),
        if (enabled) ...[
          _field('Docker socket path', socketPath, onSocketPathChanged),
          _field('Container filter', containerFilter, onContainerFilterChanged),
          SwitchListTile(
            dense: true,
            title: Text(
              'Auto-start on connect',
              style: LoggerTypography.logMeta.copyWith(
                color: LoggerColors.fgPrimary,
              ),
            ),
            value: autoStart,
            onChanged: onAutoStartChanged,
          ),
        ],
      ],
    );
  }

  Widget _field(String label, String value, ValueChanged<String> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextField(
        controller: TextEditingController(text: value),
        style: LoggerTypography.logMeta.copyWith(
          color: LoggerColors.fgPrimary,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: LoggerTypography.logMeta.copyWith(
            color: LoggerColors.fgSecondary,
          ),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 6,
          ),
          border: OutlineInputBorder(
            borderSide: const BorderSide(color: LoggerColors.borderDefault),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        onChanged: onChanged,
      ),
    );
  }
}
