import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/server_connection.dart';
import '../../services/connection_manager.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';

// ─── Status item ─────────────────────────────────────────────────────

/// A small icon + label pair used as a status bar segment.
class StatusItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isWarning;

  const StatusItem({
    super.key,
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

// ─── Connection indicator ────────────────────────────────────────────

/// Derived display state for the connection indicator.
enum ConnDisplayState { connected, reconnecting, disconnected }

/// Shows a colored dot + label reflecting the current connection state.
class ConnectionIndicator extends StatefulWidget {
  const ConnectionIndicator({super.key});

  @override
  State<ConnectionIndicator> createState() => ConnectionIndicatorState();
}

class ConnectionIndicatorState extends State<ConnectionIndicator> {
  ConnDisplayState _displayState = ConnDisplayState.disconnected;
  Timer? _disconnectTimer;
  String _label = 'disconnected';

  @override
  void dispose() {
    _disconnectTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Select only derived scalars to avoid rebuild on list reference change.
    final (:activeCount, :anyReconnecting, :displayLabel) = context
        .select<
          ConnectionManager,
          ({int activeCount, bool anyReconnecting, String displayLabel})
        >((c) {
          final conns = c.connections.values;
          final active = conns.where((c) => c.isActive);
          final reconnecting = conns.where(
            (c) => c.state == ServerConnectionState.reconnecting,
          );
          return (
            activeCount: active.length,
            anyReconnecting: reconnecting.isNotEmpty,
            displayLabel: active.length == 1
                ? active.first.displayLabel
                : active.length > 1
                ? '${active.length} connections'
                : '',
          );
        });

    // Compute target state.
    final ConnDisplayState targetState;
    final String targetLabel;
    if (activeCount > 0) {
      targetState = ConnDisplayState.connected;
      targetLabel = displayLabel;
    } else if (anyReconnecting) {
      targetState = ConnDisplayState.reconnecting;
      targetLabel = 'Reconnecting\u2026';
    } else {
      targetState = ConnDisplayState.disconnected;
      targetLabel = 'disconnected';
    }

    // Apply debounce: only show disconnected after 2s without recovery.
    if (targetState == ConnDisplayState.disconnected &&
        _displayState != ConnDisplayState.disconnected) {
      if (_disconnectTimer == null || !_disconnectTimer!.isActive) {
        _disconnectTimer = Timer(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _displayState = ConnDisplayState.disconnected;
              _label = 'disconnected';
            });
          }
        });
      }
      // Keep showing previous state during debounce.
    } else {
      _disconnectTimer?.cancel();
      _disconnectTimer = null;
      _displayState = targetState;
      _label = targetLabel;
    }

    final Color dotColor;
    final Color textColor;
    switch (_displayState) {
      case ConnDisplayState.connected:
        dotColor = LoggerColors.severityInfoText;
        textColor = LoggerColors.severityInfoText;
      case ConnDisplayState.reconnecting:
        dotColor = LoggerColors.severityWarningText;
        textColor = LoggerColors.severityWarningText;
      case ConnDisplayState.disconnected:
        dotColor = LoggerColors.severityErrorText;
        textColor = LoggerColors.fgMuted;
    }

    return GestureDetector(
      onTap: () {}, // Future: connection menu
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dotColor,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              _label,
              style: LoggerTypography.logMeta.copyWith(
                fontSize: 9,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Sticky status section ──────────────────────────────────────────

/// Shows dismissed/ignored sticky counts with a "Restore all" action.
class StickyStatusSection extends StatelessWidget {
  final int dismissed;
  final int ignored;
  final VoidCallback onRestoreAll;

  const StickyStatusSection({
    super.key,
    required this.dismissed,
    required this.ignored,
    required this.onRestoreAll,
  });

  @override
  Widget build(BuildContext context) {
    final parts = <String>[];
    if (dismissed > 0) parts.add('$dismissed dismissed');
    if (ignored > 0) parts.add('$ignored ignored');

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.push_pin_outlined, size: 10, color: LoggerColors.fgMuted),
        const SizedBox(width: 3),
        Text(
          parts.join(', '),
          style: LoggerTypography.logMeta.copyWith(
            fontSize: 9,
            color: LoggerColors.fgMuted,
          ),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: onRestoreAll,
          child: Text(
            'Restore all',
            style: LoggerTypography.logMeta.copyWith(
              fontSize: 9,
              color: LoggerColors.borderFocus,
            ),
          ),
        ),
      ],
    );
  }
}
