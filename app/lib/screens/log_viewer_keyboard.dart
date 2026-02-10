part of 'log_viewer.dart';

/// Keyboard shortcut handling for the log viewer.
mixin _KeyboardMixin on State<LogViewerScreen>, _SelectionMixin {
  bool _handleKeyEvent(KeyEvent event) {
    // Ctrl+M → toggle mini mode
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.keyM &&
        (HardwareKeyboard.instance.logicalKeysPressed.contains(
              LogicalKeyboardKey.controlLeft,
            ) ||
            HardwareKeyboard.instance.logicalKeysPressed.contains(
              LogicalKeyboardKey.controlRight,
            ))) {
      final settings = context.read<SettingsService>();
      settings.setMiniMode(!settings.miniMode);
      return true;
    }

    // Cmd+C / Ctrl+C → explicitly dispatch copy to the focused context
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.keyC &&
        (HardwareKeyboard.instance.logicalKeysPressed.contains(
              LogicalKeyboardKey.metaLeft,
            ) ||
            HardwareKeyboard.instance.logicalKeysPressed.contains(
              LogicalKeyboardKey.metaRight,
            ) ||
            HardwareKeyboard.instance.logicalKeysPressed.contains(
              LogicalKeyboardKey.controlLeft,
            ) ||
            HardwareKeyboard.instance.logicalKeysPressed.contains(
              LogicalKeyboardKey.controlRight,
            ))) {
      final ctx = primaryFocus?.context;
      if (ctx != null) {
        final action = Actions.maybeFind<CopySelectionTextIntent>(ctx);
        if (action != null) {
          Actions.invoke(ctx, CopySelectionTextIntent.copy);
          return true;
        }
      }
      return false;
    }

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
