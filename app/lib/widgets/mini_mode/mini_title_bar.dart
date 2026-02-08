import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/settings_service.dart';
import '../../services/window_service.dart';
import '../../theme/colors.dart';

/// Dense 28px titlebar for mini mode, replacing the normal SessionSelector.
///
/// Layout: App name (left) | Drag area (center) | Window control buttons (right).
class MiniTitleBar extends StatelessWidget {
  final VoidCallback? onFilterToggle;
  final VoidCallback? onSettingsToggle;
  final bool isFilterExpanded;

  const MiniTitleBar({
    super.key,
    this.onFilterToggle,
    this.onSettingsToggle,
    this.isFilterExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      color: LoggerColors.bgRaised,
      child: Row(
        children: [
          const SizedBox(width: 8),
          // Filter toggle
          _MiniButton(
            icon: Icons.filter_list,
            tooltip: 'Toggle filters',
            isActive: isFilterExpanded,
            onTap: onFilterToggle,
          ),
          // Settings toggle
          _MiniButton(
            icon: Icons.settings,
            tooltip: 'Settings',
            onTap: onSettingsToggle,
          ),
          // Expand: exit mini mode
          _MiniButton(
            icon: Icons.open_in_full,
            tooltip: 'Exit mini mode (Ctrl+M)',
            onTap: () {
              WindowService.setDecorated(true);
              context.read<SettingsService>().setMiniMode(false);
            },
          ),
          // Center: Drag area for window move
          const Expanded(child: _DragArea()),
          // Right: Window control buttons
          const _PinButton(),
          _WindowButton(
            icon: Icons.minimize,
            tooltip: 'Minimize',
            onTap: () => WindowService.minimize(),
          ),
          _WindowButton(
            icon: Icons.crop_square,
            tooltip: 'Maximize',
            onTap: () => WindowService.maximize(),
          ),
          _WindowButton(
            icon: Icons.close,
            tooltip: 'Close',
            onTap: () => WindowService.close(),
            isClose: true,
          ),
        ],
      ),
    );
  }
}

class _DragArea extends StatelessWidget {
  const _DragArea();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (_) {},
      child: const SizedBox.expand(),
    );
  }
}

class _MiniButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool isActive;
  final VoidCallback? onTap;

  const _MiniButton({
    required this.icon,
    required this.tooltip,
    this.isActive = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 24,
          height: 28,
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 12,
            color: isActive ? LoggerColors.borderFocus : LoggerColors.fgMuted,
          ),
        ),
      ),
    );
  }
}

class _PinButton extends StatefulWidget {
  const _PinButton();

  @override
  State<_PinButton> createState() => _PinButtonState();
}

class _PinButtonState extends State<_PinButton> {
  bool _pinned = false;

  @override
  Widget build(BuildContext context) {
    return _MiniButton(
      icon: Icons.push_pin_outlined,
      tooltip: 'Always on top',
      isActive: _pinned,
      onTap: () {
        setState(() => _pinned = !_pinned);
        WindowService.setAlwaysOnTop(_pinned);
      },
    );
  }
}

class _WindowButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool isClose;

  const _WindowButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.isClose = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 14,
            color: isClose
                ? LoggerColors.severityErrorText
                : LoggerColors.fgMuted,
          ),
        ),
      ),
    );
  }
}
