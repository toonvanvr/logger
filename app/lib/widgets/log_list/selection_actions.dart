import 'package:flutter/material.dart';

import '../../theme/colors.dart';
import '../../theme/typography.dart';

/// Floating action bar shown when log entries are selected in selection mode.
///
/// Renders a small horizontal bar with icon buttons for common bulk actions.
/// Positioned at the bottom-center of the log list area by the parent.
class SelectionActions extends StatelessWidget {
  final int selectedCount;
  final VoidCallback onCopy;
  final VoidCallback onExportJson;
  final VoidCallback onBookmark;
  final VoidCallback onSticky;
  final VoidCallback onClear;

  const SelectionActions({
    super.key,
    required this.selectedCount,
    required this.onCopy,
    required this.onExportJson,
    required this.onBookmark,
    required this.onSticky,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: LoggerColors.bgOverlay,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: LoggerColors.borderDefault),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ActionButton(
            icon: Icons.content_copy,
            tooltip: 'Copy',
            onTap: onCopy,
          ),
          _ActionButton(
            icon: Icons.data_object,
            tooltip: 'Export JSON',
            onTap: onExportJson,
          ),
          _ActionButton(
            icon: Icons.bookmark_outline,
            tooltip: 'Bookmark',
            onTap: onBookmark,
          ),
          _ActionButton(
            icon: Icons.push_pin_outlined,
            tooltip: 'Sticky',
            onTap: onSticky,
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: LoggerColors.bgActive,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text('$selectedCount', style: LoggerTypography.badge),
          ),
          const SizedBox(width: 4),
          _ActionButton(
            icon: Icons.close,
            tooltip: 'Clear selection',
            onTap: onClear,
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Icon(icon, size: 14, color: LoggerColors.fgSecondary),
        ),
      ),
    );
  }
}
