import 'package:flutter/foundation.dart';

/// Application-wide settings for editor integration and URL handling.
///
/// Settings are session-scoped (not persisted to disk).
class SettingsService extends ChangeNotifier {
  String _fileOpenCommand = 'code -g {file}:{line}';
  String _urlOpenCommand = 'xdg-open {url}';

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
}
