import 'package:app/services/sticky_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StickyStateService', () {
    late StickyStateService service;

    setUp(() {
      service = StickyStateService();
    });

    test('dismiss adds entry to dismissed set', () {
      service.dismiss('e1');
      expect(service.isDismissed('e1'), isTrue);
      expect(service.dismissedCount, 1);
    });

    test('restore removes entry from dismissed set', () {
      service.dismiss('e1');
      service.restore('e1');
      expect(service.isDismissed('e1'), isFalse);
      expect(service.dismissedCount, 0);
    });

    test('ignore adds group to ignored set', () {
      service.ignore('g1');
      expect(service.isGroupIgnored('g1'), isTrue);
      expect(service.ignoredGroupCount, 1);
    });

    test('restoreAll clears all state', () {
      service.dismiss('e1');
      service.dismiss('e2');
      service.ignore('g1');
      service.restoreAll();
      expect(service.dismissedCount, 0);
      expect(service.ignoredGroupCount, 0);
      expect(service.isDismissed('e1'), isFalse);
      expect(service.isGroupIgnored('g1'), isFalse);
    });

    test('notifyListeners fires on dismiss', () {
      var called = false;
      service.addListener(() => called = true);
      service.dismiss('e1');
      expect(called, isTrue);
    });

    test('notifyListeners fires on ignore', () {
      var called = false;
      service.addListener(() => called = true);
      service.ignore('g1');
      expect(called, isTrue);
    });

    test('notifyListeners fires on restore', () {
      service.dismiss('e1');
      var called = false;
      service.addListener(() => called = true);
      service.restore('e1');
      expect(called, isTrue);
    });

    test('notifyListeners fires on restoreAll', () {
      service.dismiss('e1');
      var called = false;
      service.addListener(() => called = true);
      service.restoreAll();
      expect(called, isTrue);
    });

    test('dismissedIds returns unmodifiable view', () {
      service.dismiss('e1');
      service.dismiss('e2');
      final ids = service.dismissedIds;
      expect(ids, containsAll(['e1', 'e2']));
      expect(() => ids.add('e3'), throwsUnsupportedError);
    });

    test('ignoredGroupIds returns unmodifiable view', () {
      service.ignore('g1');
      final ids = service.ignoredGroupIds;
      expect(ids, contains('g1'));
      expect(() => ids.add('g2'), throwsUnsupportedError);
    });

    test('dismiss is idempotent', () {
      service.dismiss('e1');
      service.dismiss('e1');
      expect(service.dismissedCount, 1);
    });

    test('ignore is idempotent', () {
      service.ignore('g1');
      service.ignore('g1');
      expect(service.ignoredGroupCount, 1);
    });

    test('restore non-existent entry is no-op', () {
      var called = false;
      service.addListener(() => called = true);
      service.restore('nonexistent');
      // Still fires notifyListeners (Set.remove is fine with missing keys)
      expect(called, isTrue);
      expect(service.dismissedCount, 0);
    });
  });
}
