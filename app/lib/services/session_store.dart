import 'package:flutter/foundation.dart';

import '../models/server_message.dart';

/// Manages session state for the viewer.
class SessionStore extends ChangeNotifier {
  final Map<String, SessionInfo> _sessions = {};
  final Set<String> _selectedSessionIds = {};

  /// All known sessions.
  List<SessionInfo> get sessions => _sessions.values.toList();

  /// Currently selected session IDs.
  Set<String> get selectedSessionIds => Set.unmodifiable(_selectedSessionIds);

  /// Update or insert a session.
  void updateSession(SessionInfo session) {
    _sessions[session.sessionId] = session;
    notifyListeners();
  }

  /// Update sessions from a session list message.
  void updateSessions(List<SessionInfo> sessions) {
    for (final session in sessions) {
      _sessions[session.sessionId] = session;
    }
    notifyListeners();
  }

  /// Toggle selection state for a session.
  void toggleSession(String sessionId) {
    if (_selectedSessionIds.contains(sessionId)) {
      _selectedSessionIds.remove(sessionId);
    } else {
      _selectedSessionIds.add(sessionId);
    }
    notifyListeners();
  }

  /// Select exclusively the given session (deselect all others).
  /// If the session was already the only selected one, deselect it.
  void selectOnly(String sessionId) {
    if (_selectedSessionIds.length == 1 &&
        _selectedSessionIds.contains(sessionId)) {
      _selectedSessionIds.clear();
    } else {
      _selectedSessionIds
        ..clear()
        ..add(sessionId);
    }
    notifyListeners();
  }

  /// Select all known sessions.
  void selectAll() {
    _selectedSessionIds.addAll(_sessions.keys);
    notifyListeners();
  }

  /// Deselect all sessions.
  void deselectAll() {
    _selectedSessionIds.clear();
    notifyListeners();
  }

  /// Check if a session is selected.
  bool isSelected(String sessionId) => _selectedSessionIds.contains(sessionId);

  /// Get a session by ID.
  SessionInfo? getSession(String sessionId) => _sessions[sessionId];
}
