import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../plugins/builtin/smart_search_plugin.dart';
import '../../plugins/plugin_registry.dart';
import '../../services/log_store.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';
import 'bookmark_button.dart';
import 'search_suggestions.dart';
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
  bool _isSelectingSuggestion = false;
  Timer? _overlayRemovalTimer;
  Timer? _suggestDebounce;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _overlayRemovalTimer?.cancel();
    _suggestDebounce?.cancel();
    _removeOverlay();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      _updateSuggestions(_textController.text);
      return;
    }
    if (_isSelectingSuggestion) return;
    _overlayRemovalTimer?.cancel();
    _overlayRemovalTimer = Timer(const Duration(milliseconds: 100), () {
      if (!_isSelectingSuggestion) _removeOverlay();
    });
  }

  void _updateSuggestions(String query) {
    final plugin = PluginRegistry.instance
        .getEnabledPlugins<SmartSearchPlugin>()
        .firstOrNull;
    if (plugin == null) {
      if (_suggestions.isNotEmpty) {
        setState(() => _suggestions = []);
        _removeOverlay();
      }
      return;
    }
    final suggestions = plugin.getSuggestions(
      query,
      context.read<LogStore>().entries,
    );
    setState(() => _suggestions = suggestions);
    if (suggestions.isNotEmpty && _focusNode.hasFocus) {
      _showOverlay();
    } else {
      _removeOverlay();
    }
  }

  void _showOverlay() {
    _removeOverlay();
    _overlayEntry = OverlayEntry(
      builder: (ctx) => Positioned(
        width: 320,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 30),
          child: SearchSuggestions(
            suggestions: _suggestions,
            onSelected: _onSuggestionSelected,
            onDismiss: _removeOverlay,
            onTapDown: () => _isSelectingSuggestion = true,
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
    _overlayRemovalTimer?.cancel();
    _isSelectingSuggestion = false;
    _textController.text = suggestion;
    _textController.selection = TextSelection.fromPosition(
      TextPosition(offset: suggestion.length),
    );
    widget.onTextFilterChange?.call(suggestion);
    _removeOverlay();
    _focusNode.requestFocus();
  }

  void _onTextChanged(String text) {
    widget.onTextFilterChange?.call(text);
    _suggestDebounce?.cancel();
    _suggestDebounce = Timer(
      const Duration(milliseconds: 100),
      () => _updateSuggestions(text),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _filterBarHeight,
      color: LoggerColors.bgRaised,
      padding: const EdgeInsets.symmetric(horizontal: 8),
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
                      borderRadius: BorderRadius.circular(3),
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
            const SizedBox(width: 4),
          ],
          Expanded(child: _buildSearchField()),
          const SizedBox(width: 8),
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

  Widget _buildSearchField() {
    final br = BorderRadius.circular(3);
    final border = OutlineInputBorder(
      borderSide: const BorderSide(color: LoggerColors.borderDefault),
      borderRadius: br,
    );
    return CompositedTransformTarget(
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
            border: border,
            enabledBorder: border,
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: LoggerColors.borderFocus),
              borderRadius: br,
            ),
          ),
          onChanged: _onTextChanged,
        ),
      ),
    );
  }

  void _toggleSeverity(String severity) {
    final s = Set<String>.from(widget.activeSeverities);
    s.contains(severity) ? s.remove(severity) : s.add(severity);
    widget.onSeverityChange?.call(s);
  }
}
