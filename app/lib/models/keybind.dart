import 'package:flutter/services.dart';

/// A keyboard shortcut definition.
class Keybind {
  final String id;
  final String label;
  final String category;
  final LogicalKeyboardKey key;
  final bool ctrl;
  final bool shift;
  final bool alt;
  final bool meta;

  const Keybind({
    required this.id,
    required this.label,
    required this.category,
    required this.key,
    this.ctrl = false,
    this.shift = false,
    this.alt = false,
    this.meta = false,
  });

  /// Check if a key event matches this keybind.
  bool matches(KeyEvent event) {
    if (event.logicalKey != key) return false;
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    final hasCtrl = pressed.contains(LogicalKeyboardKey.controlLeft) ||
        pressed.contains(LogicalKeyboardKey.controlRight);
    final hasShift = pressed.contains(LogicalKeyboardKey.shiftLeft) ||
        pressed.contains(LogicalKeyboardKey.shiftRight);
    final hasAlt = pressed.contains(LogicalKeyboardKey.altLeft) ||
        pressed.contains(LogicalKeyboardKey.altRight);
    final hasMeta = pressed.contains(LogicalKeyboardKey.metaLeft) ||
        pressed.contains(LogicalKeyboardKey.metaRight);
    return hasCtrl == ctrl &&
        hasShift == shift &&
        hasAlt == alt &&
        hasMeta == meta;
  }

  @override
  String toString() => 'Keybind($id: $shortcutLabel)';

  /// Human-readable label like "Ctrl+Shift+M".
  String get shortcutLabel {
    final parts = <String>[];
    if (ctrl) parts.add('Ctrl');
    if (shift) parts.add('Shift');
    if (alt) parts.add('Alt');
    if (meta) parts.add('Meta');
    parts.add(key.keyLabel);
    return parts.join('+');
  }
}
