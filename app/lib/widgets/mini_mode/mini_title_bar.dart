import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/settings_service.dart';
import '../../services/window_service.dart';
import '../../theme/colors.dart';
import '../landing/landing_helpers.dart';

/// Dense 28px titlebar for mini mode, replacing the normal SessionSelector.
///
/// Layout: App name (left) | Drag area (center) | Window control buttons (right).
class MiniTitleBar extends StatelessWidget {
  final VoidCallback? onSettingsToggle;

  const MiniTitleBar({
    super.key,
    this.onSettingsToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      color: LoggerColors.bgRaised,
      child: Row(
        children: [
          const SizedBox(width: 8),
          SizedBox(
            width: 14,
            height: 14,
            child: CustomPaint(painter: LogoPainter()),
          ),
          const SizedBox(width: 4),
          const Expanded(child: _DragArea()),
          _MiniButton(
            icon: Icons.settings,
            tooltip: 'Settings',
            onTap: onSettingsToggle,
          ),
          _MiniButton(
            icon: Icons.open_in_full,
            tooltip: 'Exit mini mode (Ctrl+M)',
            onTap: () {
              WindowService.setDecorated(true);
              context.read<SettingsService>().setMiniMode(false);
            },
          ),
          const _PinButton(),
          _WindowButton(
            icon: Icons.minimize,
            tooltip: 'Minimize',
            onTap: () => WindowService.minimize(),
          ),
          const _MaximizeButton(),
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
    return Listener(
      onPointerDown: (_) => WindowService.startDrag(),
      child: const MouseRegion(
        cursor: SystemMouseCursors.move,
        child: SizedBox.expand(),
      ),
    );
  }
}

class _MiniButton extends StatefulWidget {
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
  State<_MiniButton> createState() => _MiniButtonState();
}

class _MiniButtonState extends State<_MiniButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.isActive
        ? LoggerColors.borderFocus
        : _isHovered
        ? LoggerColors.fgPrimary
        : LoggerColors.fgMuted;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Tooltip(
        message: widget.tooltip,
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: 32,
            height: 28,
            alignment: Alignment.center,
            child: TweenAnimationBuilder<Color?>(
              tween: ColorTween(end: color),
              duration: const Duration(milliseconds: 150),
              builder: (context, value, child) {
                return Icon(widget.icon, size: 12, color: value);
              },
            ),
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

class _MaximizeButton extends StatefulWidget {
  const _MaximizeButton();

  @override
  State<_MaximizeButton> createState() => _MaximizeButtonState();
}

class _MaximizeButtonState extends State<_MaximizeButton> {
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    _queryState();
  }

  Future<void> _queryState() async {
    final maximized = await WindowService.isMaximized();
    if (mounted) setState(() => _isMaximized = maximized);
  }

  @override
  Widget build(BuildContext context) {
    return _WindowButton(
      icon: _isMaximized ? Icons.filter_none : Icons.crop_square,
      tooltip: _isMaximized ? 'Restore' : 'Maximize',
      onTap: () async {
        await WindowService.maximize();
        if (mounted) setState(() => _isMaximized = !_isMaximized);
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
