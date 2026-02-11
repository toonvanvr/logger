import 'package:app/models/keybind.dart';
import 'package:app/services/keybind_registry.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('KeybindRegistry', () {
    late KeybindRegistry registry;

    setUp(() {
      registry = KeybindRegistry();
    });

    test('initial state has no keybinds', () {
      expect(registry.keybinds, isEmpty);
      expect(registry.keybindsByCategory, isEmpty);
    });

    test('register adds keybind and notifies', () {
      var notified = false;
      registry.addListener(() => notified = true);

      registry.register(
        const Keybind(
          id: 'test',
          label: 'Test',
          category: 'General',
          key: LogicalKeyboardKey.keyT,
          ctrl: true,
        ),
        () => true,
      );

      expect(registry.keybinds, hasLength(1));
      expect(registry.keybinds.first.id, 'test');
      expect(notified, true);
    });

    test('unregister removes keybind and notifies', () {
      registry.register(
        const Keybind(
          id: 'test',
          label: 'Test',
          category: 'General',
          key: LogicalKeyboardKey.keyT,
        ),
        () => true,
      );

      var notified = false;
      registry.addListener(() => notified = true);

      registry.unregister('test');
      expect(registry.keybinds, isEmpty);
      expect(notified, true);
    });

    test('unregister with unknown id does not notify', () {
      var notified = false;
      registry.addListener(() => notified = true);

      registry.unregister('nonexistent');
      expect(notified, false);
    });

    test('keybindsByCategory groups correctly', () {
      registry.register(
        const Keybind(
          id: 'a',
          label: 'A',
          category: 'View',
          key: LogicalKeyboardKey.keyA,
        ),
        () => true,
      );
      registry.register(
        const Keybind(
          id: 'b',
          label: 'B',
          category: 'Edit',
          key: LogicalKeyboardKey.keyB,
        ),
        () => true,
      );
      registry.register(
        const Keybind(
          id: 'c',
          label: 'C',
          category: 'View',
          key: LogicalKeyboardKey.keyC,
        ),
        () => true,
      );

      final grouped = registry.keybindsByCategory;
      expect(grouped.keys, containsAll(['View', 'Edit']));
      expect(grouped['View'], hasLength(2));
      expect(grouped['Edit'], hasLength(1));
    });

    test('multiple keybinds can be registered', () {
      registry.register(
        const Keybind(
          id: 'one',
          label: 'One',
          category: 'Nav',
          key: LogicalKeyboardKey.digit1,
        ),
        () => true,
      );
      registry.register(
        const Keybind(
          id: 'two',
          label: 'Two',
          category: 'Nav',
          key: LogicalKeyboardKey.digit2,
        ),
        () => true,
      );

      expect(registry.keybinds, hasLength(2));
    });

    test('re-registering same id overwrites', () {
      registry.register(
        const Keybind(
          id: 'dup',
          label: 'First',
          category: 'General',
          key: LogicalKeyboardKey.keyA,
        ),
        () => true,
      );
      registry.register(
        const Keybind(
          id: 'dup',
          label: 'Second',
          category: 'General',
          key: LogicalKeyboardKey.keyB,
        ),
        () => false,
      );

      expect(registry.keybinds, hasLength(1));
      expect(registry.keybinds.first.label, 'Second');
    });
  });

  group('Keybind', () {
    test('shortcutLabel formats correctly', () {
      const kb = Keybind(
        id: 'test',
        label: 'Test',
        category: 'General',
        key: LogicalKeyboardKey.keyM,
        ctrl: true,
      );
      expect(kb.shortcutLabel, 'Ctrl+M');
    });

    test('shortcutLabel with multiple modifiers', () {
      const kb = Keybind(
        id: 'test',
        label: 'Test',
        category: 'General',
        key: LogicalKeyboardKey.keyS,
        ctrl: true,
        shift: true,
      );
      expect(kb.shortcutLabel, 'Ctrl+Shift+S');
    });

    test('toString includes id and shortcut', () {
      const kb = Keybind(
        id: 'save',
        label: 'Save',
        category: 'File',
        key: LogicalKeyboardKey.keyS,
        ctrl: true,
      );
      expect(kb.toString(), 'Keybind(save: Ctrl+S)');
    });
  });
}
