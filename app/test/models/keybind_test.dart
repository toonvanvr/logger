import 'package:app/models/keybind.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Keybind', () {
    test('constructor sets required fields', () {
      const kb = Keybind(
        id: 'test',
        label: 'Test Action',
        category: 'general',
        key: LogicalKeyboardKey.keyA,
      );

      expect(kb.id, 'test');
      expect(kb.label, 'Test Action');
      expect(kb.category, 'general');
      expect(kb.key, LogicalKeyboardKey.keyA);
    });

    test('modifier defaults are false', () {
      const kb = Keybind(
        id: 'test',
        label: 'Test',
        category: 'general',
        key: LogicalKeyboardKey.keyA,
      );

      expect(kb.ctrl, isFalse);
      expect(kb.shift, isFalse);
      expect(kb.alt, isFalse);
      expect(kb.meta, isFalse);
    });

    test('modifier flags can be set', () {
      const kb = Keybind(
        id: 'test',
        label: 'Test',
        category: 'general',
        key: LogicalKeyboardKey.keyA,
        ctrl: true,
        shift: true,
        alt: true,
        meta: true,
      );

      expect(kb.ctrl, isTrue);
      expect(kb.shift, isTrue);
      expect(kb.alt, isTrue);
      expect(kb.meta, isTrue);
    });
  });

  group('Keybind.shortcutLabel', () {
    test('returns key label alone when no modifiers', () {
      const kb = Keybind(
        id: 'test',
        label: 'Test',
        category: 'general',
        key: LogicalKeyboardKey.keyA,
      );
      expect(kb.shortcutLabel, 'A');
    });

    test('includes Ctrl prefix', () {
      const kb = Keybind(
        id: 'test',
        label: 'Test',
        category: 'general',
        key: LogicalKeyboardKey.keyA,
        ctrl: true,
      );
      expect(kb.shortcutLabel, 'Ctrl+A');
    });

    test('includes all modifiers in order', () {
      const kb = Keybind(
        id: 'test',
        label: 'Test',
        category: 'general',
        key: LogicalKeyboardKey.keyM,
        ctrl: true,
        shift: true,
        alt: true,
        meta: true,
      );
      expect(kb.shortcutLabel, 'Ctrl+Shift+Alt+Meta+M');
    });
  });

  group('Keybind.toString', () {
    test('includes id and shortcutLabel', () {
      const kb = Keybind(
        id: 'copy',
        label: 'Copy',
        category: 'edit',
        key: LogicalKeyboardKey.keyC,
        ctrl: true,
      );
      expect(kb.toString(), 'Keybind(copy: Ctrl+C)');
    });
  });
}
