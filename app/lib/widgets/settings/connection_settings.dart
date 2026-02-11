import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/server_connection.dart';
import '../../services/connection_manager.dart';
import '../../theme/colors.dart';
import '../../theme/constants.dart';
import '../../theme/typography.dart';
import 'settings_text_field.dart';

/// Config sub-panel for managing server connections.
class ConnectionSettings extends StatelessWidget {
  const ConnectionSettings({super.key});

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<ConnectionManager>();
    final connections = manager.connections;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final entry in connections.entries)
          _ConnectionEntry(
            connection: entry.value,
            onToggle: () => manager.toggleConnection(entry.key),
            onDelete: () => manager.removeConnection(entry.key),
            onUrlChanged: (url) => manager.updateConnection(
              entry.key,
              entry.value.copyWith(url: url),
            ),
          ),
        const SizedBox(height: 8),
        _AddConnectionButton(
          onAdd: () =>
              manager.addConnection('ws://localhost:8080/api/v2/stream'),
        ),
      ],
    );
  }
}

// ─── Connection entry row ────────────────────────────────────────────

class _ConnectionEntry extends StatelessWidget {
  final ServerConnection connection;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final ValueChanged<String> onUrlChanged;

  const _ConnectionEntry({
    required this.connection,
    required this.onToggle,
    required this.onDelete,
    required this.onUrlChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          _stateDot(connection.state),
          const SizedBox(width: 8),
          Expanded(
            child: SettingsTextField(
              value: connection.url,
              onChanged: onUrlChanged,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onToggle,
            child: Icon(
              connection.enabled ? Icons.link : Icons.link_off,
              size: 14,
              color: connection.enabled
                  ? LoggerColors.severityInfoText
                  : LoggerColors.fgMuted,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onDelete,
            child: const Icon(
              Icons.close,
              size: 14,
              color: LoggerColors.fgMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stateDot(ServerConnectionState state) {
    final color = switch (state) {
      ServerConnectionState.connected => LoggerColors.severityInfoText,
      ServerConnectionState.connecting ||
      ServerConnectionState.reconnecting => LoggerColors.severityWarningText,
      ServerConnectionState.failed => LoggerColors.severityErrorText,
      ServerConnectionState.disconnected => LoggerColors.fgMuted,
    };
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

// ─── Add connection button ───────────────────────────────────────────

class _AddConnectionButton extends StatelessWidget {
  final VoidCallback onAdd;
  const _AddConnectionButton({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onAdd,
      child: Container(
        height: 28,
        decoration: BoxDecoration(
          border: Border.all(color: LoggerColors.borderSubtle),
          borderRadius: kBorderRadius,
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add, size: 14, color: LoggerColors.fgMuted),
            const SizedBox(width: 4),
            Text(
              'Add connection',
              style: LoggerTypography.logMeta.copyWith(
                color: LoggerColors.fgSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
