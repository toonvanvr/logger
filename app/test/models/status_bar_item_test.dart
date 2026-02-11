import 'package:app/models/status_bar_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StatusBarAlignment', () {
    test('has left and right values', () {
      expect(StatusBarAlignment.values, hasLength(2));
      expect(StatusBarAlignment.values, contains(StatusBarAlignment.left));
      expect(StatusBarAlignment.values, contains(StatusBarAlignment.right));
    });
  });

  group('StatusBarItem', () {
    test('constructor sets required fields', () {
      const item = StatusBarItem(id: 'count', label: '42 entries');
      expect(item.id, 'count');
      expect(item.label, '42 entries');
    });

    test('defaults are correct', () {
      const item = StatusBarItem(id: 'count', label: '42');
      expect(item.icon, isNull);
      expect(item.priority, 100);
      expect(item.alignment, StatusBarAlignment.left);
      expect(item.onTap, isNull);
    });

    test('accepts optional fields', () {
      var tapped = false;
      final item = StatusBarItem(
        id: 'errors',
        label: '3 errors',
        icon: Icons.error,
        priority: 10,
        alignment: StatusBarAlignment.right,
        onTap: () => tapped = true,
      );

      expect(item.icon, Icons.error);
      expect(item.priority, 10);
      expect(item.alignment, StatusBarAlignment.right);
      item.onTap!();
      expect(tapped, isTrue);
    });
  });
}
