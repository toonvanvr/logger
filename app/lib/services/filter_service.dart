import 'package:flutter/foundation.dart';

/// Default severity set used when clearing filters.
const Set<String> defaultSeverities = {
  'debug',
  'info',
  'warning',
  'error',
  'critical',
};

/// Centralized filter state for the log viewer.
///
/// Holds severity selection, text filter, state filter stack, and flat mode.
/// Widgets watch this via Provider instead of relying on setState in the
/// top-level screen mixin.
class FilterService extends ChangeNotifier {
  Set<String> _activeSeverities = Set.of(defaultSeverities);
  String _textFilter = '';
  List<String> _stateFilterStack = [];
  bool _flatMode = false;

  // ---------------------------------------------------------------------------
  // Getters
  // ---------------------------------------------------------------------------

  Set<String> get activeSeverities => _activeSeverities;
  String get textFilter => _textFilter;
  List<String> get stateFilterStack => List.unmodifiable(_stateFilterStack);
  Set<String> get activeStateFilters => _stateFilterStack.toSet();
  bool get flatMode => _flatMode;

  /// Composes the effective filter from user text and state filter stack.
  String get effectiveFilter {
    final parts = [
      _textFilter,
      ..._stateFilterStack.map((k) => 'state:$k'),
    ].where((s) => s.isNotEmpty);
    return parts.join(' ');
  }

  /// Whether any filter is active (non-default).
  bool get hasActiveFilters =>
      _textFilter.isNotEmpty ||
      _stateFilterStack.isNotEmpty ||
      _activeSeverities.length != defaultSeverities.length ||
      _flatMode;

  // ---------------------------------------------------------------------------
  // Setters
  // ---------------------------------------------------------------------------

  void setSeverities(Set<String> severities) {
    if (setEquals(_activeSeverities, severities)) return;
    _activeSeverities = severities;
    notifyListeners();
  }

  void setTextFilter(String text) {
    if (_textFilter == text) return;
    _textFilter = text;
    notifyListeners();
  }

  void setFlatMode(bool value) {
    if (_flatMode == value) return;
    _flatMode = value;
    notifyListeners();
  }

  /// Toggles a state key in/out of the filter stack.
  void toggleStateFilter(String stateKey) {
    if (_stateFilterStack.contains(stateKey)) {
      _stateFilterStack.remove(stateKey);
    } else {
      _stateFilterStack.add(stateKey);
    }
    notifyListeners();
  }

  /// Removes a state filter from the stack.
  void removeStateFilter(String stateKey) {
    if (_stateFilterStack.remove(stateKey)) {
      notifyListeners();
    }
  }

  /// Loads a saved query into the filter state.
  void loadQuery({
    required Set<String> severities,
    required String textFilter,
  }) {
    _activeSeverities = Set.of(severities);
    _textFilter = textFilter;
    _stateFilterStack = [];
    notifyListeners();
  }

  /// Resets all filters to defaults.
  void clear() {
    _activeSeverities = Set.of(defaultSeverities);
    _textFilter = '';
    _stateFilterStack = [];
    _flatMode = false;
    notifyListeners();
  }
}
