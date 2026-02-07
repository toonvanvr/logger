import 'package:flutter/material.dart';

import '../../theme/colors.dart';
import '../../theme/typography.dart';

const _filterBarHeight = 32.0;

const _severities = ['debug', 'info', 'warning', 'error', 'critical'];

/// Collapsible filter bar with severity toggles and text search.
class FilterBar extends StatelessWidget {
  /// Currently active severity levels.
  final Set<String> activeSeverities;

  /// Called when severity selection changes.
  final ValueChanged<Set<String>>? onSeverityChange;

  /// Called when the text filter changes.
  final ValueChanged<String>? onTextFilterChange;

  /// Called when the clear-all button is pressed.
  final VoidCallback? onClear;

  const FilterBar({
    super.key,
    this.activeSeverities = const {
      'debug',
      'info',
      'warning',
      'error',
      'critical',
    },
    this.onSeverityChange,
    this.onTextFilterChange,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _filterBarHeight,
      color: LoggerColors.bgRaised,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          // Severity toggles
          for (final severity in _severities)
            Padding(
              padding: const EdgeInsets.only(right: 2),
              child: _SeverityToggle(
                severity: severity,
                isActive: activeSeverities.contains(severity),
                onToggle: () => _toggleSeverity(severity),
              ),
            ),
          const SizedBox(width: 8),
          // Text search
          Expanded(
            child: SizedBox(
              height: 22,
              child: TextField(
                style: LoggerTypography.logMeta.copyWith(
                  color: LoggerColors.fgPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Filter...',
                  hintStyle: LoggerTypography.logMeta.copyWith(
                    color: LoggerColors.fgMuted,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 0,
                  ),
                  isDense: true,
                  filled: true,
                  fillColor: LoggerColors.bgSurface,
                  border: OutlineInputBorder(
                    borderSide: const BorderSide(
                      color: LoggerColors.borderDefault,
                    ),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(
                      color: LoggerColors.borderDefault,
                    ),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(
                      color: LoggerColors.borderFocus,
                    ),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                onChanged: onTextFilterChange,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Clear all
          GestureDetector(
            onTap: onClear,
            child: const Tooltip(
              message: 'Clear all filters',
              child: Icon(
                Icons.clear_all,
                size: 16,
                color: LoggerColors.fgMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleSeverity(String severity) {
    final updated = Set<String>.from(activeSeverities);
    if (updated.contains(severity)) {
      updated.remove(severity);
    } else {
      updated.add(severity);
    }
    onSeverityChange?.call(updated);
  }
}

class _SeverityToggle extends StatelessWidget {
  final String severity;
  final bool isActive;
  final VoidCallback onToggle;

  const _SeverityToggle({
    required this.severity,
    required this.isActive,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final color = severityBarColor(severity);

    return GestureDetector(
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: isActive ? color.withAlpha(51) : Colors.transparent,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: isActive ? color : LoggerColors.borderDefault,
            width: 1,
          ),
        ),
        child: Text(
          severity[0].toUpperCase(),
          style: LoggerTypography.badge.copyWith(
            color: isActive ? color : LoggerColors.fgMuted,
          ),
        ),
      ),
    );
  }
}
