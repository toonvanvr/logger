import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/keybind.dart';

/// Callback type for keybind actions.
typedef KeybindAction = bool Function();

/// Central registry for keyboard shortcuts.
///
/// Manages keybind registration, dispatch, and provides a queryable
/// list for UI display (e.g., help overlay, settings panel).
class KeybindRegistry extends ChangeNotifier {
  final Map<String, _RegisteredKeybind> _bindings = {};

  /// All registered keybinds (for UI display / help screen).
  List<Keybind> get keybinds =>
      _bindings.values.map((r) => r.keybind).toList(growable: false);

  /// Keybinds grouped by category.
  Map<String, List<Keybind>> get keybindsByCategory {
    final map = <String, List<Keybind>>{};
    for (final r in _bindings.values) {
      map.putIfAbsent(r.keybind.category, () => []).add(r.keybind);
    }
    return map;
  }

  /// Register a keybind with its action callback.
  void register(Keybind keybind, KeybindAction action) {
    _bindings[keybind.id] = _RegisteredKeybind(keybind, action);
    notifyListeners();
  }

  /// Unregister a keybind by id.
  void unregister(String id) {
    if (_bindings.remove(id) != null) {
      notifyListeners();
    }
  }

  /// Handle a key event. Returns true if consumed.
  bool handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    for (final entry in _bindings.values) {
      if (entry.keybind.matches(event)) {
        return entry.action();
      }
    }
    return false;
  }

  @override
  void dispose() {
    _bindings.clear();
    super.dispose();
  }
}

class _RegisteredKeybind {
  final Keybind keybind;
  final KeybindAction action;
  const _RegisteredKeybind(this.keybind, this.action);
}
