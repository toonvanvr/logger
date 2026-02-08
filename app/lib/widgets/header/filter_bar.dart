import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../plugins/builtin/smart_search_plugin.dart';
import '../../plugins/plugin_registry.dart';
import '../../services/log_store.dart';
import '../../services/query_store.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';
import 'search_suggestions.dart';

const _filterBarHeight = 32.0;

const _severities = ['debug', 'info', 'warning', 'error', 'critical'];

/// Collapsible filter bar with severity toggles and text search.
class FilterBar extends StatefulWidget {
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
  State<FilterBar> createState() => _FilterBarState();
}

class _FilterBarState extends State<FilterBar> {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  final _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  List<String> _suggestions = [];

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _removeOverlay();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      _updateSuggestions(_textController.text);
    } else {
      _removeOverlay();
    }
  }

  void _updateSuggestions(String query) {
    final plugin = PluginRegistry.instance
        .getEnabledPlugins<SmartSearchPlugin>()
        .firstOrNull;
    if (plugin == null) {
      _removeSuggestionsIfEmpty();
      return;
    }

    final logStore = context.read<LogStore>();
    final suggestions = plugin.getSuggestions(query, logStore.entries);

    setState(() => _suggestions = suggestions);

    if (suggestions.isNotEmpty && _focusNode.hasFocus) {
      _showOverlay();
    } else {
      _removeOverlay();
    }
  }

  void _removeSuggestionsIfEmpty() {
    if (_suggestions.isEmpty) return;
    setState(() => _suggestions = []);
    _removeOverlay();
  }

  void _showOverlay() {
    _removeOverlay();
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: 320,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 30),
          child: SearchSuggestions(
            suggestions: _suggestions,
            onSelected: _onSuggestionSelected,
            onDismiss: _removeOverlay,
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _onSuggestionSelected(String suggestion) {
    _textController.text = suggestion;
    _textController.selection = TextSelection.fromPosition(
      TextPosition(offset: suggestion.length),
    );
    widget.onTextFilterChange?.call(suggestion);
    _removeOverlay();
  }

  void _onTextChanged(String text) {
    widget.onTextFilterChange?.call(text);
    _updateSuggestions(text);
  }

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
                isActive: widget.activeSeverities.contains(severity),
                onToggle: () => _toggleSeverity(severity),
              ),
            ),
          const SizedBox(width: 8),
          // Text search with suggestion overlay
          Expanded(
            child: CompositedTransformTarget(
              link: _layerLink,
              child: SizedBox(
                height: 28,
                child: TextField(
                  controller: _textController,
                  focusNode: _focusNode,
                  style: LoggerTypography.logMeta.copyWith(
                    color: LoggerColors.fgPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Filter... (try uuid:, url:, error:)',
                    hintStyle: LoggerTypography.logMeta.copyWith(
                      color: LoggerColors.fgMuted,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
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
                  onChanged: _onTextChanged,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Saved query bookmarks
          _BookmarkButton(
            activeSeverities: widget.activeSeverities,
            textFilter: _textController.text,
            onQueryLoaded: (query) {
              _textController.text = query.textFilter;
              _textController.selection = TextSelection.fromPosition(
                TextPosition(offset: query.textFilter.length),
              );
            },
          ),
          const SizedBox(width: 4),
          // Clear all
          GestureDetector(
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
        ],
      ),
    );
  }

  void _toggleSeverity(String severity) {
    final updated = Set<String>.from(widget.activeSeverities);
    if (updated.contains(severity)) {
      updated.remove(severity);
    } else {
      updated.add(severity);
    }
    widget.onSeverityChange?.call(updated);
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

/// Bookmark icon button that shows saved queries in a popup menu.
class _BookmarkButton extends StatelessWidget {
  final Set<String> activeSeverities;
  final String textFilter;
  final ValueChanged<SavedQuery> onQueryLoaded;

  const _BookmarkButton({
    required this.activeSeverities,
    required this.textFilter,
    required this.onQueryLoaded,
  });

  @override
  Widget build(BuildContext context) {
    final queryStore = context.watch<QueryStore>();
    final hasSaved = queryStore.queries.isNotEmpty;

    return PopupMenuButton<_BookmarkAction>(
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      tooltip: 'Saved queries',
      icon: Icon(
        hasSaved ? Icons.bookmark : Icons.bookmark_border,
        size: 16,
        color: LoggerColors.fgMuted,
      ),
      iconSize: 16,
      color: LoggerColors.bgOverlay,
      onSelected: (action) => _handleAction(context, action),
      itemBuilder: (context) => _buildMenuItems(queryStore),
    );
  }

  List<PopupMenuEntry<_BookmarkAction>> _buildMenuItems(QueryStore queryStore) {
    final items = <PopupMenuEntry<_BookmarkAction>>[];

    // Save current option
    items.add(
      PopupMenuItem(
        value: _BookmarkAction.save,
        child: Row(
          children: [
            const Icon(Icons.save, size: 14, color: LoggerColors.fgSecondary),
            const SizedBox(width: 8),
            Text(
              'Save current filters',
              style: LoggerTypography.logMeta.copyWith(
                color: LoggerColors.fgPrimary,
              ),
            ),
          ],
        ),
      ),
    );

    if (queryStore.queries.isNotEmpty) {
      items.add(const PopupMenuDivider(height: 1));

      for (var i = 0; i < queryStore.queries.length; i++) {
        final query = queryStore.queries[i];
        items.add(
          PopupMenuItem(
            value: _BookmarkAction.load(i),
            child: Text(
              query.name,
              style: LoggerTypography.logMeta.copyWith(
                color: LoggerColors.fgPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      }
    }

    return items;
  }

  void _handleAction(BuildContext context, _BookmarkAction action) {
    final queryStore = context.read<QueryStore>();

    switch (action) {
      case _BookmarkSave():
        _showSaveDialog(context, queryStore);
      case _BookmarkLoad(:final index):
        if (index < queryStore.queries.length) {
          final query = queryStore.queries[index];
          queryStore.loadQuery(query);
          onQueryLoaded(query);
        }
    }
  }

  void _showSaveDialog(BuildContext context, QueryStore queryStore) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: LoggerColors.bgOverlay,
        title: Text(
          'Save Query',
          style: LoggerTypography.logMeta.copyWith(
            color: LoggerColors.fgPrimary,
            fontSize: 14,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: LoggerTypography.logMeta.copyWith(
            color: LoggerColors.fgPrimary,
          ),
          decoration: InputDecoration(
            hintText: 'Query name',
            hintStyle: LoggerTypography.logMeta.copyWith(
              color: LoggerColors.fgMuted,
            ),
          ),
          onSubmitted: (name) {
            if (name.trim().isNotEmpty) {
              queryStore.saveQuery(
                name.trim(),
                severities: activeSeverities,
                textFilter: textFilter,
              );
              Navigator.of(ctx).pop();
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: LoggerTypography.logMeta.copyWith(
                color: LoggerColors.fgMuted,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                queryStore.saveQuery(
                  name,
                  severities: activeSeverities,
                  textFilter: textFilter,
                );
                Navigator.of(ctx).pop();
              }
            },
            child: Text(
              'Save',
              style: LoggerTypography.logMeta.copyWith(
                color: LoggerColors.borderFocus,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Internal action type for the bookmark popup menu.
sealed class _BookmarkAction {
  const _BookmarkAction();
  static const save = _BookmarkSave();
  static _BookmarkLoad load(int index) => _BookmarkLoad(index);
}

class _BookmarkSave extends _BookmarkAction {
  const _BookmarkSave();
}

class _BookmarkLoad extends _BookmarkAction {
  final int index;
  const _BookmarkLoad(this.index);
}
