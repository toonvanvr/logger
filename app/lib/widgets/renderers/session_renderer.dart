import 'package:flutter/material.dart';

import '../../models/log_entry.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';

/// Renders session lifecycle events (start, end, heartbeat).
class SessionRenderer extends StatelessWidget {
  final LogEntry entry;

  const SessionRenderer({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final action = entry.sessionAction ?? SessionAction.start;
    final app = entry.application;
    final appName = app?.name ?? 'App';
    final version = app?.version;

    return switch (action) {
      SessionAction.start => _buildStart(appName, version),
      SessionAction.end => _buildEnd(appName),
      SessionAction.heartbeat => _buildHeartbeat(),
    };
  }

  Widget _buildStart(String appName, String? version) {
    final label = version != null
        ? 'Session started: $appName v$version'
        : 'Session started: $appName';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: LoggerColors.syntaxString, // green
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: LoggerTypography.logBody),
      ],
    );
  }

  Widget _buildEnd(String appName) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: LoggerColors.fgMuted, // gray
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          'Session ended: $appName',
          style: LoggerTypography.logBody.copyWith(
            color: LoggerColors.fgSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildHeartbeat() {
    return Text(
      'heartbeat',
      style: LoggerTypography.logMeta.copyWith(color: LoggerColors.fgMuted),
    );
  }
}
