import 'package:flutter/material.dart';

import '../../services/window_service.dart';
import '../../theme/colors.dart';

const _headerHeight = 40.0;

// ─── Connection indicator ────────────────────────────────────────────

/// Small colored dot indicating WebSocket connection status.
class ConnectionIndicator extends StatelessWidget {
  final bool isConnected;
  const ConnectionIndicator({super.key, required this.isConnected});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: isConnected ? 'Connected' : 'Disconnected',
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: isConnected
              ? const Color(0xFFA8CC7E)
              : const Color(0xFFE06C60),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// ─── Header icon button ──────────────────────────────────────────────

/// Reusable icon button for the header bar (filter toggle, RPC toggle, etc.).
class HeaderIconButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final bool isActive;
  final VoidCallback? onTap;

  const HeaderIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.isActive = false,
    this.onTap,
  });

  @override
  State<HeaderIconButton> createState() => _HeaderIconButtonState();
}

class _HeaderIconButtonState extends State<HeaderIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Tooltip(
        message: widget.tooltip,
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: 28,
            height: _headerHeight,
            alignment: Alignment.center,
            color: _hovered ? LoggerColors.bgHover : Colors.transparent,
            child: Icon(
              widget.icon,
              size: 14,
              color: widget.isActive
                  ? LoggerColors.borderFocus
                  : LoggerColors.fgMuted,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Always-on-top button ────────────────────────────────────────────

/// Pin button that toggles the window always-on-top state.
class AlwaysOnTopButton extends StatefulWidget {
  const AlwaysOnTopButton({super.key});

  @override
  State<AlwaysOnTopButton> createState() => _AlwaysOnTopButtonState();
}

class _AlwaysOnTopButtonState extends State<AlwaysOnTopButton> {
  bool _pinned = false;

  @override
  Widget build(BuildContext context) {
    return HeaderIconButton(
      icon: Icons.push_pin_outlined,
      tooltip: 'Always on top',
      isActive: _pinned,
      onTap: () async {
        final newState = !_pinned;
        try {
          await WindowService.setAlwaysOnTop(newState);
          setState(() => _pinned = newState);
        } catch (e) {
          debugPrint('Always-on-top not supported: $e');
        }
      },
    );
  }
}
