import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Returns the platform-appropriate default command for opening URLs.
String _defaultUrlOpenCommand() {
  if (Platform.isMacOS) return 'open {url}';
  if (Platform.isWindows) return 'start {url}';
  return 'xdg-open {url}';
}

/// Application-wide settings for editor integration and URL handling.
///
/// Settings are session-scoped (not persisted to disk).
class SettingsService extends ChangeNotifier {
  String _fileOpenCommand = 'code -g {file}:{line}';
  String _urlOpenCommand = _defaultUrlOpenCommand();

  /// Command template for opening files in an editor.
  /// Placeholders: `{file}` and `{line}`.
  String get fileOpenCommand => _fileOpenCommand;

  /// Command template for opening URLs.
  /// Placeholder: `{url}`.
  String get urlOpenCommand => _urlOpenCommand;

  /// Update the file-open command template.
  void setFileOpenCommand(String cmd) {
    _fileOpenCommand = cmd;
    notifyListeners();
  }

  /// Update the URL-open command template.
  void setUrlOpenCommand(String cmd) {
    _urlOpenCommand = cmd;
    notifyListeners();
  }

  // ─── Layout & Connection Settings ──────────────────────────────

  bool _miniMode = true;
  bool _stateViewCollapsed = false;
  bool _shelfCollapsed = true;
  List<Map<String, dynamic>> _connections = [];

  /// Whether the compact title bar mode is active.
  bool get miniMode => _miniMode;

  /// Whether the state view section is collapsed.
  bool get stateViewCollapsed => _stateViewCollapsed;

  /// Whether the secondary shelf is collapsed (default: true).
  bool get shelfCollapsed => _shelfCollapsed;

  /// Persisted connection configurations.
  List<Map<String, dynamic>> get connections => List.unmodifiable(_connections);

  /// Toggle compact title bar mode.
  void setMiniMode(bool value) {
    _miniMode = value;
    notifyListeners();
  }

  /// Toggle state view section collapsed.
  void setStateViewCollapsed(bool value) {
    _stateViewCollapsed = value;
    notifyListeners();
  }

  /// Toggle secondary shelf collapsed.
  void setShelfCollapsed(bool value) {
    _shelfCollapsed = value;
    notifyListeners();
  }

  /// Update persisted connection configurations.
  void setConnections(List<Map<String, dynamic>> value) {
    _connections = value;
    notifyListeners();
  }
}
