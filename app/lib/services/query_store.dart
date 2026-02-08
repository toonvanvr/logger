import 'package:flutter/foundation.dart';

/// A saved search/filter preset (bookmark).
class SavedQuery {
  final String name;
  final Set<String> severities;
  final String textFilter;
  final Set<String>? sessionIds;
  final DateTime savedAt;

  const SavedQuery({
    required this.name,
    required this.severities,
    required this.textFilter,
    this.sessionIds,
    required this.savedAt,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SavedQuery &&
          runtimeType == other.runtimeType &&
          name == other.name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => 'SavedQuery($name)';
}

/// Manages saved query bookmarks for the filter bar.
///
/// Queries are stored in-memory for the current viewer session.
/// Exposes a [loadedQuery] callback mechanism so the filter bar
/// can react to loaded queries.
class QueryStore extends ChangeNotifier {
  final List<SavedQuery> _queries = [];

  /// Callback invoked when a saved query is loaded.
  /// The filter bar should listen to this to apply the query.
  ValueChanged<SavedQuery>? onQueryLoaded;

  /// All saved queries in insertion order.
  List<SavedQuery> get queries => List.unmodifiable(_queries);

  /// Number of saved queries.
  int get length => _queries.length;

  /// Save the current filter state as a named bookmark.
  void saveQuery(
    String name, {
    required Set<String> severities,
    required String textFilter,
    Set<String>? sessionIds,
  }) {
    // Replace existing query with same name
    _queries.removeWhere((q) => q.name == name);

    _queries.add(
      SavedQuery(
        name: name,
        severities: Set.unmodifiable(severities),
        textFilter: textFilter,
        sessionIds: sessionIds != null ? Set.unmodifiable(sessionIds) : null,
        savedAt: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  /// Delete a saved query by index.
  void deleteQuery(int index) {
    if (index < 0 || index >= _queries.length) return;
    _queries.removeAt(index);
    notifyListeners();
  }

  /// Load (apply) a saved query. Invokes [onQueryLoaded] callback.
  void loadQuery(SavedQuery query) {
    onQueryLoaded?.call(query);
  }
}
