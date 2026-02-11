import 'package:flutter/material.dart';

import '../../theme/colors.dart';
import '../../theme/constants.dart';
import '../../theme/typography.dart';
import 'bookmark_button.dart';
import 'filter_suggestions.dart';
import 'severity_toggle.dart';

const _filterBarHeight = 32.0;

const _severities = ['debug', 'info', 'warning', 'error', 'critical'];

/// Collapsible filter bar with severity toggles and text search.
class FilterBar extends StatefulWidget {
  final Set<String> activeSeverities;
  final ValueChanged<Set<String>>? onSeverityChange;
  final ValueChanged<String>? onTextFilterChange;
  final VoidCallback? onClear;
  final Set<String> activeStateFilters;
  final ValueChanged<String>? onStateFilterRemove;
  final bool flatMode;
  final ValueChanged<bool>? onFlatModeToggle;

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
    this.activeStateFilters = const {},
    this.onStateFilterRemove,
    this.flatMode = false,
    this.onFlatModeToggle,
  });

  @override
  State<FilterBar> createState() => _FilterBarState();
}

class _FilterBarState extends State<FilterBar> {
  final _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _filterBarHeight,
      color: LoggerColors.bgRaised,
      padding: kHPadding8,
      child: Row(
        children: [
          for (final severity in _severities)
            Padding(
              padding: const EdgeInsets.only(right: 2),
              child: SeverityToggle(
                severity: severity,
                isActive: widget.activeSeverities.contains(severity),
                onToggle: () => _toggleSeverity(severity),
              ),
            ),
          const SizedBox(width: 8),
          if (widget.activeStateFilters.isNotEmpty) ...[
            for (final key in widget.activeStateFilters)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => widget.onStateFilterRemove?.call(key),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: LoggerColors.severityInfoBar.withValues(
                          alpha: 0.15,
                        ),
                        borderRadius: kBorderRadiusSm,
                        border: Border.all(
                          color: LoggerColors.severityInfoBar.withValues(
                            alpha: 0.4,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'state:$key',
                            style: LoggerTypography.logMeta.copyWith(
                              color: LoggerColors.fgPrimary,
                              fontSize: 10,
                            ),
                          ),
                          const SizedBox(width: 3),
                          const Icon(
                            Icons.close,
                            size: 10,
                            color: LoggerColors.fgMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: FilterSearchField(
              controller: _textController,
              onTextFilterChange: widget.onTextFilterChange,
            ),
          ),
          const SizedBox(width: 4),
          _buildFlatModeToggle(),
          const SizedBox(width: 4),
          BookmarkButton(
            activeSeverities: widget.activeSeverities,
            textFilter: _textController.text,
            onQueryLoaded: (q) {
              _textController.text = q.textFilter;
              _textController.selection = TextSelection.fromPosition(
                TextPosition(offset: q.textFilter.length),
              );
            },
          ),
          const SizedBox(width: 4),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: widget.onClear,
              child: const Tooltip(
                message: 'Clear all filters',
                child: Icon(
                  Icons.clear_all,
                  size: 16,
                  color: LoggerColors.fgMuted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlatModeToggle() => MouseRegion(
    cursor: SystemMouseCursors.click,
    child: GestureDetector(
      onTap: () => widget.onFlatModeToggle?.call(!widget.flatMode),
      child: Tooltip(
        message: widget.flatMode ? 'Grouped view' : 'Flat view',
        child: SizedBox(
          width: 28,
          height: 28,
          child: Icon(
            widget.flatMode ? Icons.view_list : Icons.account_tree,
            size: 16,
            color: widget.flatMode
                ? LoggerColors.borderFocus
                : LoggerColors.fgMuted,
          ),
        ),
      ),
    ),
  );

  void _toggleSeverity(String severity) {
    final s = Set<String>.from(widget.activeSeverities);
    s.contains(severity) ? s.remove(severity) : s.add(severity);
    widget.onSeverityChange?.call(s);
  }
}
