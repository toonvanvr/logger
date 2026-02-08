import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/log_connection.dart';
import '../../services/log_store.dart';
import '../../services/session_store.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';

/// A subtle status bar at the bottom of the app showing entry count,
/// memory estimate, and connection status.
class StatusBar extends StatelessWidget {
  const StatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    final logStore = context.watch<LogStore>();
    final sessionStore = context.watch<SessionStore>();
    final connection = context.watch<LogConnection>();

    return Container(
      height: 20,
      color: LoggerColors.bgBase,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          // Left: entry count
          _StatusItem(
            icon: Icons.storage_outlined,
            label: '${logStore.entryCount} entries',
            isWarning: logStore.entryCount > 8000,
          ),
          const SizedBox(width: 12),
          // Memory estimate
          _StatusItem(
            icon: Icons.memory_outlined,
            label: _formatMemory(logStore.estimatedMemoryBytes),
            isWarning: logStore.estimatedMemoryBytes > 100 * 1024 * 1024,
          ),
          const Spacer(),
          // Right: connection status
          _ConnectionIndicator(
            connected: connection.isConnected,
            sessionCount: sessionStore.sessions.length,
          ),
        ],
      ),
    );
  }

  static String _formatMemory(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

// ─── Private widgets ─────────────────────────────────────────────────

class _StatusItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isWarning;

  const _StatusItem({
    required this.icon,
    required this.label,
    this.isWarning = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isWarning
        ? LoggerColors.severityWarningText
        : LoggerColors.fgMuted;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 3),
        Text(
          label,
          style: LoggerTypography.logMeta.copyWith(fontSize: 9, color: color),
        ),
      ],
    );
  }
}

class _ConnectionIndicator extends StatelessWidget {
  final bool connected;
  final int sessionCount;

  const _ConnectionIndicator({
    required this.connected,
    required this.sessionCount,
  });

  @override
  Widget build(BuildContext context) {
    final color = connected
        ? LoggerColors.severityInfoText
        : LoggerColors.fgMuted;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: connected
                ? LoggerColors.severityInfoText
                : LoggerColors.severityErrorText,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          connected
              ? '$sessionCount session${sessionCount == 1 ? '' : 's'}'
              : 'disconnected',
          style: LoggerTypography.logMeta.copyWith(fontSize: 9, color: color),
        ),
      ],
    );
  }
}
