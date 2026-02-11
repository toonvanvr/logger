import 'package:flutter/material.dart';

import '../../plugins/plugin_registry.dart';
import '../../plugins/plugin_types.dart';
import '../../theme/colors.dart';
import '../../version.dart';
import 'connection_settings.dart';
import 'settings_panel_header.dart';
import 'editor_sub_panel.dart';
import 'tool_group.dart';
import 'tool_row.dart';

part 'settings_panel_content.dart';

/// Slide-out settings sidebar with grouped plugin tools.
class SettingsPanel extends StatefulWidget {
  final bool isVisible;
  final VoidCallback onClose;

  const SettingsPanel({
    super.key,
    required this.isVisible,
    required this.onClose,
  });

  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _isRendered = false;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.dismissed) {
        setState(() => _isRendered = false);
      }
    });
    if (widget.isVisible) {
      _isRendered = true;
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant SettingsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible && !oldWidget.isVisible) {
      setState(() => _isRendered = true);
      _controller.forward();
    } else if (!widget.isVisible && oldWidget.isVisible) {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isRendered) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => ClipRect(
        child: Align(
          alignment: Alignment.centerRight,
          widthFactor: _controller.value,
          child: child,
        ),
      ),
      child: SizedBox(
        width: 300,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: LoggerColors.bgRaised,
            border: Border(
              left: BorderSide(color: LoggerColors.borderSubtle, width: 1),
            ),
          ),
          child: _PanelContent(onClose: widget.onClose),
        ),
      ),
    );
  }
}
