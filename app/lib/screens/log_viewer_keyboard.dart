part of 'log_viewer.dart';

/// Keyboard shortcut handling for the log viewer.
mixin _KeyboardMixin on State<LogViewerScreen>, _SelectionMixin {
  /// Register keybinds with the central registry.
  ///
  /// Called from postFrameCallback so [context] is available.
  void _registerKeybinds() {
    final registry = context.read<KeybindRegistry>();

    registry.register(
      const Keybind(
        id: 'toggle_mini',
        label: 'Toggle mini mode',
        category: 'View',
        key: LogicalKeyboardKey.keyM,
        ctrl: true,
      ),
      () {
        final settings = context.read<SettingsService>();
        settings.setMiniMode(!settings.miniMode);
        return true;
      },
    );

    registry.register(
      const Keybind(
        id: 'copy',
        label: 'Copy selection',
        category: 'Edit',
        key: LogicalKeyboardKey.keyC,
        ctrl: true,
      ),
      () {
        final ctx = primaryFocus?.context;
        if (ctx != null) {
          final action = Actions.maybeFind<CopySelectionTextIntent>(ctx);
          if (action != null) {
            Actions.invoke(ctx, CopySelectionTextIntent.copy);
            return true;
          }
        }
        return false;
      },
    );
  }

  bool _handleKeyEvent(KeyEvent event) {
    // Delegate to registry first
    final registry = context.read<KeybindRegistry>();
    if (registry.handleKeyEvent(event)) return true;

    // Shift hold for selection mode (stateful — stays in mixin)
    if (event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.shiftLeft ||
            event.logicalKey == LogicalKeyboardKey.shiftRight)) {
      if (!_selectionMode) {
        setState(() => _selectionMode = true);
      }
      return false;
    }
    if (event is KeyUpEvent &&
        (event.logicalKey == LogicalKeyboardKey.shiftLeft ||
            event.logicalKey == LogicalKeyboardKey.shiftRight)) {
      if (_selectionMode && _selectedEntryIds.isEmpty) {
        setState(() => _selectionMode = false);
      }
      return false;
    }
    return false;
  }
}
