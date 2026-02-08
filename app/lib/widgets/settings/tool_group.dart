import 'package:flutter/material.dart';

import '../../theme/colors.dart';
import '../../theme/typography.dart';

/// Collapsible group in the settings panel containing [ToolRow] children.
class ToolGroup extends StatefulWidget {
  final String title;
  final List<Widget> children;
  final bool initiallyExpanded;

  const ToolGroup({
    super.key,
    required this.title,
    required this.children,
    this.initiallyExpanded = true,
  });

  @override
  State<ToolGroup> createState() => _ToolGroupState();
}

class _ToolGroupState extends State<ToolGroup>
    with SingleTickerProviderStateMixin {
  late bool _expanded;
  late final AnimationController _controller;
  late final Animation<double> _sizeFactor;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
      value: _expanded ? 1.0 : 0.0,
    );
    _sizeFactor = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _expanded = !_expanded;
      if (_expanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: _toggle,
          child: Container(
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            color: LoggerColors.bgSurface,
            child: Row(
              children: [
                Icon(
                  _expanded ? Icons.expand_more : Icons.chevron_right,
                  size: 14,
                  color: LoggerColors.fgMuted,
                ),
                const SizedBox(width: 4),
                Text(
                  widget.title.toUpperCase(),
                  style: LoggerTypography.sectionH.copyWith(
                    color: LoggerColors.fgSecondary,
                    fontSize: 10,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizeTransition(
          sizeFactor: _sizeFactor,
          child: Column(children: widget.children),
        ),
      ],
    );
  }
}
