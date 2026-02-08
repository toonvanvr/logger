/// Status bar item model for plugin-contributed status indicators.
library;

import 'package:flutter/material.dart';

/// Alignment of a status bar item.
enum StatusBarAlignment { left, right }

/// A single item displayed in the status bar.
class StatusBarItem {
  final String id;
  final String label;
  final IconData? icon;
  final int priority; // lower = first
  final StatusBarAlignment alignment;
  final VoidCallback? onTap;

  const StatusBarItem({
    required this.id,
    required this.label,
    this.icon,
    this.priority = 100,
    this.alignment = StatusBarAlignment.left,
    this.onTap,
  });
}
