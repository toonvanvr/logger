import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/server_connection.dart';
import '../../services/connection_manager.dart';
import '../../services/log_store.dart';
import '../../services/sticky_state.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';

/// A subtle status bar at the bottom of the app showing entry count,
/// memory estimate, and connection status.
class StatusBar extends StatelessWidget {
  const StatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    final entryCount = context.select<LogStore, int>((s) => s.entryCount);
    final memoryBytes = context.select<LogStore, int>(
      (s) => s.estimatedMemoryBytes,
    );
    final stickyState = context.watch<StickyStateService>();

    final dismissed = stickyState.dismissedCount;
    final ignored = stickyState.ignoredGroupCount;
    final hasStickyInfo = dismissed > 0 || ignored > 0;

    return Container(
      height: 20,
      color: LoggerColors.bgBase,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 400;
          return Row(
            children: [
              _StatusItem(
                icon: Icons.storage_outlined,
                label: '$entryCount entries',
                isWarning: entryCount > 8000,
              ),
              if (!narrow) ...[
                const SizedBox(width: 12),
                _StatusItem(
                  icon: Icons.memory_outlined,
                  label: _formatMemory(memoryBytes),
                  isWarning: memoryBytes > 100 * 1024 * 1024,
                ),
              ],
              if (hasStickyInfo && !narrow) ...[
                const SizedBox(width: 12),
                _StickyStatusSection(
                  dismissed: dismissed,
                  ignored: ignored,
                  onRestoreAll: stickyState.restoreAll,
                ),
              ],
              const Spacer(),
              const _ConnectionIndicator(),
            ],
          );
        },
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

class _ConnectionIndicator extends StatefulWidget {
  const _ConnectionIndicator();

  @override
  State<_ConnectionIndicator> createState() => _ConnectionIndicatorState();
}

/// Derived display state for the connection indicator.
enum _ConnDisplayState { connected, reconnecting, disconnected }

class _ConnectionIndicatorState extends State<_ConnectionIndicator> {
  _ConnDisplayState _displayState = _ConnDisplayState.disconnected;
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
    final _ConnDisplayState targetState;
    final String targetLabel;
    if (activeCount > 0) {
      targetState = _ConnDisplayState.connected;
      targetLabel = displayLabel;
    } else if (anyReconnecting) {
      targetState = _ConnDisplayState.reconnecting;
      targetLabel = 'Reconnecting\u2026';
    } else {
      targetState = _ConnDisplayState.disconnected;
      targetLabel = 'disconnected';
    }

    // Apply debounce: only show disconnected after 2s without recovery.
    if (targetState == _ConnDisplayState.disconnected &&
        _displayState != _ConnDisplayState.disconnected) {
      if (_disconnectTimer == null || !_disconnectTimer!.isActive) {
        _disconnectTimer = Timer(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _displayState = _ConnDisplayState.disconnected;
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
      case _ConnDisplayState.connected:
        dotColor = LoggerColors.severityInfoText;
        textColor = LoggerColors.severityInfoText;
      case _ConnDisplayState.reconnecting:
        dotColor = LoggerColors.severityWarningText;
        textColor = LoggerColors.severityWarningText;
      case _ConnDisplayState.disconnected:
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

/// S06: Shows dismissed/ignored sticky counts with a "Restore all" action.
class _StickyStatusSection extends StatelessWidget {
  final int dismissed;
  final int ignored;
  final VoidCallback onRestoreAll;

  const _StickyStatusSection({
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
