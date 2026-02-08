import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/colors.dart';
import '../../theme/typography.dart';

/// A dropdown overlay showing autocomplete suggestions grouped by pattern type.
///
/// Displays up to [maxVisible] items with scrolling. Keyboard navigable
/// (up/down arrows, enter to select, escape to dismiss).
class SearchSuggestions extends StatefulWidget {
  /// The suggestions to display.
  final List<String> suggestions;

  /// Called when a suggestion is selected.
  final ValueChanged<String> onSelected;

  /// Called when the overlay should be dismissed.
  final VoidCallback onDismiss;

  /// Maximum visible suggestion count before scrolling.
  final int maxVisible;

  const SearchSuggestions({
    super.key,
    required this.suggestions,
    required this.onSelected,
    required this.onDismiss,
    this.maxVisible = 8,
  });

  @override
  State<SearchSuggestions> createState() => _SearchSuggestionsState();
}

class _SearchSuggestionsState extends State<SearchSuggestions> {
  int _highlightedIndex = -1;
  final _scrollController = ScrollController();

  @override
  void didUpdateWidget(SearchSuggestions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.suggestions != oldWidget.suggestions) {
      _highlightedIndex = -1;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _moveHighlight(int delta) {
    setState(() {
      final len = widget.suggestions.length;
      if (len == 0) return;
      _highlightedIndex = (_highlightedIndex + delta).clamp(-1, len - 1);
      if (_highlightedIndex < 0) _highlightedIndex = len - 1;
      _ensureVisible();
    });
  }

  void _ensureVisible() {
    if (_highlightedIndex < 0) return;
    const itemHeight = 28.0;
    final offset = _highlightedIndex * itemHeight;
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        offset.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 60),
        curve: Curves.easeOut,
      );
    }
  }

  void _selectCurrent() {
    if (_highlightedIndex >= 0 &&
        _highlightedIndex < widget.suggestions.length) {
      widget.onSelected(widget.suggestions[_highlightedIndex]);
    }
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _moveHighlight(1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _moveHighlight(-1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      _selectCurrent();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      widget.onDismiss();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.suggestions.isEmpty) return const SizedBox.shrink();

    const itemHeight = 28.0;
    final visibleCount = widget.suggestions.length.clamp(1, widget.maxVisible);
    final height = visibleCount * itemHeight;

    return Focus(
      onKeyEvent: _handleKey,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: LoggerColors.bgOverlay,
          border: Border.all(color: LoggerColors.borderSubtle),
          borderRadius: BorderRadius.circular(4),
          boxShadow: const [
            BoxShadow(
              color: Color(0x40000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: ListView.builder(
          controller: _scrollController,
          padding: EdgeInsets.zero,
          itemCount: widget.suggestions.length,
          itemExtent: itemHeight,
          itemBuilder: (context, index) {
            final suggestion = widget.suggestions[index];
            final isHighlighted = index == _highlightedIndex;
            final isPrefix = suggestion.endsWith(':');

            return GestureDetector(
              onTap: () => widget.onSelected(suggestion),
              child: MouseRegion(
                onEnter: (_) => setState(() => _highlightedIndex = index),
                child: Container(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  color: isHighlighted
                      ? LoggerColors.bgActive
                      : Colors.transparent,
                  child: Row(
                    children: [
                      if (isPrefix)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Icon(
                            _prefixIcon(suggestion),
                            size: 12,
                            color: LoggerColors.fgMuted,
                          ),
                        ),
                      Expanded(
                        child: Text(
                          suggestion,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: LoggerTypography.logMeta.copyWith(
                            color: isHighlighted
                                ? LoggerColors.fgPrimary
                                : LoggerColors.fgSecondary,
                            fontWeight: isPrefix
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                      if (isPrefix)
                        Text(
                          _prefixHint(suggestion),
                          style: LoggerTypography.logMeta.copyWith(
                            color: LoggerColors.fgMuted,
                            fontSize: 9,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  static IconData _prefixIcon(String prefix) {
    return switch (prefix) {
      'uuid:' => Icons.fingerprint,
      'url:' => Icons.link,
      'email:' => Icons.email_outlined,
      'ip:' => Icons.router_outlined,
      'error:' => Icons.error_outline,
      'status:' => Icons.http,
      _ => Icons.search,
    };
  }

  static String _prefixHint(String prefix) {
    return switch (prefix) {
      'uuid:' => 'UUID pattern',
      'url:' => 'URL pattern',
      'email:' => 'Email pattern',
      'ip:' => 'IP address',
      'error:' => 'Error keywords',
      'status:' => 'HTTP status',
      _ => '',
    };
  }
}
