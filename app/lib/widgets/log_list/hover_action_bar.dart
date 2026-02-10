import 'package:flutter/material.dart';

import '../../models/log_entry.dart';
import '../../plugins/plugin_types.dart';
import '../../theme/colors.dart';

/// Horizontal row of icon action buttons shown on log row hover.
///
/// Renders up to [maxVisible] icons. If actions exceed that, the last
/// slot becomes an overflow [PopupMenuButton].
class HoverActionBar extends StatelessWidget {
  final LogEntry entry;
  final Color backgroundColor;
  final List<RowAction> actions;
  final int maxVisible;

  const HoverActionBar({
    super.key,
    required this.entry,
    required this.backgroundColor,
    required this.actions,
    this.maxVisible = 5,
  });

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();

    final showOverflow = actions.length > maxVisible;
    final visible = showOverflow ? actions.sublist(0, maxVisible - 1) : actions;
    final overflow = showOverflow
        ? actions.sublist(maxVisible - 1)
        : <RowAction>[];

    return Container(
      color: backgroundColor,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final action in visible)
            _ActionIcon(
              action: action,
              entry: entry,
              backgroundColor: backgroundColor,
            ),
          if (showOverflow)
            _OverflowMenuIcon(
              actions: overflow,
              entry: entry,
              backgroundColor: backgroundColor,
            ),
        ],
      ),
    );
  }
}

// ─── Single action icon button ───────────────────────────────────────

class _ActionIcon extends StatefulWidget {
  final RowAction action;
  final LogEntry entry;
  final Color backgroundColor;

  const _ActionIcon({
    required this.action,
    required this.entry,
    required this.backgroundColor,
  });

  @override
  State<_ActionIcon> createState() => _ActionIconState();
}

class _ActionIconState extends State<_ActionIcon> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.action.isActive?.call(widget.entry) ?? false;
    final color = active
        ? LoggerColors.syntaxString
        : _hovered
        ? LoggerColors.fgPrimary
        : LoggerColors.fgMuted;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => widget.action.onTap(widget.entry),
        child: Tooltip(
          message: widget.action.tooltip,
          waitDuration: const Duration(milliseconds: 500),
          child: Container(
            width: 24,
            color: widget.backgroundColor,
            alignment: Alignment.center,
            child: Icon(widget.action.icon, size: 14, color: color),
          ),
        ),
      ),
    );
  }
}

// ─── Overflow popup for excess actions ───────────────────────────────

class _OverflowMenuIcon extends StatefulWidget {
  final List<RowAction> actions;
  final LogEntry entry;
  final Color backgroundColor;

  const _OverflowMenuIcon({
    required this.actions,
    required this.entry,
    required this.backgroundColor,
  });

  @override
  State<_OverflowMenuIcon> createState() => _OverflowMenuIconState();
}

class _OverflowMenuIconState extends State<_OverflowMenuIcon> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = _hovered ? LoggerColors.fgPrimary : LoggerColors.fgMuted;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: PopupMenuButton<RowAction>(
        tooltip: 'More actions',
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        position: PopupMenuPosition.under,
        onSelected: (action) => action.onTap(widget.entry),
        itemBuilder: (_) => widget.actions
            .map(
              (a) => PopupMenuItem(
                value: a,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(a.icon, size: 14),
                    const SizedBox(width: 8),
                    Text(a.tooltip),
                  ],
                ),
              ),
            )
            .toList(),
        child: Container(
          width: 24,
          color: widget.backgroundColor,
          alignment: Alignment.center,
          child: Icon(Icons.more_horiz, size: 14, color: color),
        ),
      ),
    );
  }
}
