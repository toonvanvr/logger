import 'package:app/models/log_entry.dart';
import 'package:app/widgets/log_list/log_list_builder.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers.dart';

LogEntry _makeEntry({
  required String id,
  Severity severity = Severity.info,
  EntryKind kind = EntryKind.event,
  String? message,
  DisplayLocation display = DisplayLocation.defaultLoc,
  String? groupId,
  String? parentId,
}) {
  return makeTestEntry(
    id: id,
    severity: severity,
    kind: kind,
    message: message,
    display: display,
    groupId: groupId,
    parentId: parentId,
  );
}

void main() {
  group('processGrouping stickyOverrideIds', () {
    test('marks entries in stickyOverrideIds as sticky', () {
      final entries = [
        _makeEntry(id: 'a', message: 'first'),
        _makeEntry(id: 'b', message: 'second'),
        _makeEntry(id: 'c', message: 'third'),
      ];

      final result = processGrouping(
        entries: entries,
        textFilter: null,
        collapsedGroups: {},
        stickyOverrideIds: {'b'},
      );

      expect(result.length, 3);
      expect(result[0].isSticky, false);
      expect(result[1].isSticky, true);
      expect(result[2].isSticky, false);
    });

    test(
      'protocol static_ display does not auto-sticky; only override works',
      () {
        final entries = [
          _makeEntry(
            id: 'a',
            message: 'protocol sticky',
            display: DisplayLocation.static_,
          ),
          _makeEntry(id: 'b', message: 'override sticky'),
          _makeEntry(id: 'c', message: 'not sticky'),
        ];

        final result = processGrouping(
          entries: entries,
          textFilter: null,
          collapsedGroups: {},
          stickyOverrideIds: {'b'},
        );

        expect(result[0].isSticky, false); // protocol alone not sticky
        expect(result[1].isSticky, true); // override
        expect(result[2].isSticky, false);
      },
    );

    test('override on already-sticky entry is no-op', () {
      final entries = [
        _makeEntry(id: 'a', message: 'both', display: DisplayLocation.static_),
      ];

      final result = processGrouping(
        entries: entries,
        textFilter: null,
        collapsedGroups: {},
        stickyOverrideIds: {'a'},
      );

      expect(result[0].isSticky, true);
    });

    test('null stickyOverrideIds has no effect', () {
      final entries = [_makeEntry(id: 'a', message: 'normal')];

      final result = processGrouping(
        entries: entries,
        textFilter: null,
        collapsedGroups: {},
      );

      expect(result[0].isSticky, false);
    });

    test('empty stickyOverrideIds marks nothing as sticky', () {
      final entries = [_makeEntry(id: 'a', message: 'normal')];

      final result = processGrouping(
        entries: entries,
        textFilter: null,
        collapsedGroups: {},
        stickyOverrideIds: {},
      );

      expect(result[0].isSticky, false);
    });
  });

  group('processGrouping basic grouping', () {
    test('computes correct depth for group header and child', () {
      final entries = [
        _makeEntry(id: 'g1', groupId: 'grp1', message: 'Outer'),
        _makeEntry(id: 'a', message: 'inside outer', parentId: 'grp1'),
      ];

      final result = processGrouping(
        entries: entries,
        textFilter: null,
        collapsedGroups: {},
      );

      expect(result.length, 2);
      expect(result[0].depth, 0); // group header
      expect(result[1].depth, 1); // child
    });

    test('hides entries in collapsed groups', () {
      final entries = [
        _makeEntry(id: 'g1', groupId: 'grp1', message: 'Group'),
        _makeEntry(id: 'a', message: 'hidden child', parentId: 'grp1'),
      ];

      final result = processGrouping(
        entries: entries,
        textFilter: null,
        collapsedGroups: {'grp1'},
      );

      // Group header visible, child hidden
      expect(result.length, 1);
      expect(result[0].entry.id, 'g1');
    });
  });

  group('processGrouping nested groups', () {
    test('computes depth for deeply nested groups', () {
      final entries = [
        _makeEntry(id: 'g1', groupId: 'outer', message: 'Outer'),
        _makeEntry(
          id: 'g2',
          groupId: 'inner',
          parentId: 'outer',
          message: 'Inner',
        ),
        _makeEntry(id: 'a', message: 'deep', parentId: 'inner'),
      ];

      final result = processGrouping(
        entries: entries,
        textFilter: null,
        collapsedGroups: {},
      );

      expect(result.length, 3);
      expect(result[0].depth, 0); // outer header
      expect(result[1].depth, 1); // inner header (child of outer)
      expect(result[2].depth, 2); // leaf child
    });

    test('collapsing outer hides inner group and its children', () {
      final entries = [
        _makeEntry(id: 'g1', groupId: 'outer', message: 'Outer'),
        _makeEntry(
          id: 'g2',
          groupId: 'inner',
          parentId: 'outer',
          message: 'Inner',
        ),
        _makeEntry(id: 'a', message: 'deep', parentId: 'inner'),
      ];

      final result = processGrouping(
        entries: entries,
        textFilter: null,
        collapsedGroups: {'outer'},
      );

      // Only outer header visible
      expect(result.length, 1);
      expect(result[0].entry.id, 'g1');
    });

    test('collapsing inner hides only its children', () {
      final entries = [
        _makeEntry(id: 'g1', groupId: 'outer', message: 'Outer'),
        _makeEntry(
          id: 'g2',
          groupId: 'inner',
          parentId: 'outer',
          message: 'Inner',
        ),
        _makeEntry(id: 'a', message: 'deep', parentId: 'inner'),
        _makeEntry(id: 'b', message: 'sibling', parentId: 'outer'),
      ];

      final result = processGrouping(
        entries: entries,
        textFilter: null,
        collapsedGroups: {'inner'},
      );

      // Outer header + inner header + sibling visible, deep hidden
      expect(result.length, 3);
      expect(result[0].entry.id, 'g1');
      expect(result[1].entry.id, 'g2');
      expect(result[2].entry.id, 'b');
    });

    test('entries without group have zero depth', () {
      final entries = [
        _makeEntry(id: 'g1', groupId: 'grp1', message: 'Group'),
        _makeEntry(id: 'a', message: 'child', parentId: 'grp1'),
        _makeEntry(id: 'b', message: 'top-level'),
      ];

      final result = processGrouping(
        entries: entries,
        textFilter: null,
        collapsedGroups: {},
      );

      expect(result.length, 3);
      expect(result[2].depth, 0);
      expect(result[2].parentGroupId, isNull);
    });
  });
}
