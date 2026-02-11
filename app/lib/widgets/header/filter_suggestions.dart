import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../plugins/builtin/smart_search_plugin.dart';
import '../../plugins/plugin_registry.dart';
import '../../services/log_store.dart';
import '../../theme/colors.dart';
import '../../theme/constants.dart';
import '../../theme/typography.dart';
import 'search_suggestions.dart';

/// A search text field with smart suggestion overlay.
///
/// Manages the suggestion overlay lifecycle, debounced queries,
/// and keyboard/focus interactions for filter autocomplete.
class FilterSearchField extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onTextFilterChange;

  const FilterSearchField({
    super.key,
    required this.controller,
    this.onTextFilterChange,
  });

  @override
  State<FilterSearchField> createState() => _FilterSearchFieldState();
}

class _FilterSearchFieldState extends State<FilterSearchField> {
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
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      _updateSuggestions(widget.controller.text);
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
    widget.controller.text = suggestion;
    widget.controller.selection = TextSelection.fromPosition(
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
    final br = kBorderRadiusSm;
    final border = OutlineInputBorder(
      borderSide: const BorderSide(color: LoggerColors.borderDefault),
      borderRadius: br,
    );
    return CompositedTransformTarget(
      link: _layerLink,
      child: SizedBox(
        height: 28,
        child: TextField(
          controller: widget.controller,
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
}
