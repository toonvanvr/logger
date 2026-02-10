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
  Map<String, String>? labels,
}) {
  return makeTestEntry(
    id: id,
    severity: severity,
    kind: kind,
    message: message,
    display: display,
    groupId: groupId,
    parentId: parentId,
    labels: labels,
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

    test('server sticky labels detected', () {
      final entries = [
        _makeEntry(
          id: 'a',
          message: 'server pinned',
          labels: {'_sticky': 'true'},
        ),
        _makeEntry(id: 'b', message: 'normal'),
      ];

      final result = processGrouping(
        entries: entries,
        textFilter: null,
        collapsedGroups: {},
      );

      expect(result[0].isSticky, true);
      expect(result[1].isSticky, false);
    });

    test('mixed sticky sources — both override and labels', () {
      final entries = [
        _makeEntry(
          id: 'a',
          message: 'both sources',
          labels: {'_sticky': 'true'},
        ),
        _makeEntry(id: 'b', message: 'override only'),
      ];

      final result = processGrouping(
        entries: entries,
        textFilter: null,
        collapsedGroups: {},
        stickyOverrideIds: {'a', 'b'},
      );

      expect(result[0].isSticky, true);
      expect(result[1].isSticky, true);
    });
  });

  group('processGrouping basic grouping', () {
    test('computes correct depth for group header and child', () {
      // v2: header has id == groupId (self-ref), child has groupId set
      final entries = [
        _makeEntry(id: 'grp1', groupId: 'grp1', message: 'Outer'),
        _makeEntry(id: 'a', groupId: 'grp1', message: 'inside outer'),
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
        _makeEntry(id: 'grp1', groupId: 'grp1', message: 'Group'),
        _makeEntry(id: 'a', groupId: 'grp1', message: 'hidden child'),
      ];

      final result = processGrouping(
        entries: entries,
        textFilter: null,
        collapsedGroups: {'grp1'},
      );

      // Group header visible, child hidden
      expect(result.length, 1);
      expect(result[0].entry.id, 'grp1');
    });

    test('group close entries are filtered out', () {
      final entries = [
        _makeEntry(id: 'grp1', groupId: 'grp1', message: 'Group'),
        _makeEntry(id: 'a', groupId: 'grp1', message: 'child'),
        // Close sentinel: groupId set, message empty, id != groupId
        _makeEntry(id: 'close1', groupId: 'grp1', message: ''),
      ];

      final result = processGrouping(
        entries: entries,
        textFilter: null,
        collapsedGroups: {},
      );

      expect(result.length, 2);
      expect(result[0].entry.id, 'grp1');
      expect(result[1].entry.id, 'a');
    });

    test('unpin entries are filtered out', () {
      final entries = [
        _makeEntry(id: 'a', message: 'normal'),
        _makeEntry(
          id: 'unpin1',
          message: '',
          labels: {'_sticky_action': 'unpin'},
        ),
        _makeEntry(id: 'b', message: 'also normal'),
      ];

      final result = processGrouping(
        entries: entries,
        textFilter: null,
        collapsedGroups: {},
      );

      expect(result.length, 2);
      expect(result[0].entry.id, 'a');
      expect(result[1].entry.id, 'b');
    });

    test('non-header group members get correct depth', () {
      final entries = [
        _makeEntry(id: 'grp1', groupId: 'grp1', message: 'My Group'),
        _makeEntry(id: 'c1', groupId: 'grp1', message: 'child 1'),
        _makeEntry(id: 'c2', groupId: 'grp1', message: 'child 2'),
      ];

      final result = processGrouping(
        entries: entries,
        textFilter: null,
        collapsedGroups: {},
      );

      expect(result.length, 3);
      expect(result[0].depth, 0); // header
      expect(result[1].depth, 1); // child
      expect(result[2].depth, 1); // child
    });
  });

  group('processGrouping nested groups', () {
    test('computes depth for deeply nested groups', () {
      // v2: nested group headers are self-ref, nesting by entry order
      final entries = [
        _makeEntry(id: 'outer', groupId: 'outer', message: 'Outer'),
        _makeEntry(id: 'inner', groupId: 'inner', message: 'Inner'),
        _makeEntry(id: 'a', groupId: 'inner', message: 'deep'),
        // close inner
        _makeEntry(id: 'close-inner', groupId: 'inner', message: ''),
        // close outer
        _makeEntry(id: 'close-outer', groupId: 'outer', message: ''),
      ];

      final result = processGrouping(
        entries: entries,
        textFilter: null,
        collapsedGroups: {},
      );

      // close entries filtered, so 3 results
      expect(result.length, 3);
      expect(result[0].depth, 0); // outer header
      expect(result[1].depth, 1); // inner header (child of outer)
      expect(result[2].depth, 2); // leaf child
    });

    test('collapsing outer hides inner group and its children', () {
      final entries = [
        _makeEntry(id: 'outer', groupId: 'outer', message: 'Outer'),
        _makeEntry(id: 'inner', groupId: 'inner', message: 'Inner'),
        _makeEntry(id: 'a', groupId: 'inner', message: 'deep'),
        _makeEntry(id: 'close-inner', groupId: 'inner', message: ''),
        _makeEntry(id: 'close-outer', groupId: 'outer', message: ''),
      ];

      final result = processGrouping(
        entries: entries,
        textFilter: null,
        collapsedGroups: {'outer'},
      );

      // Only outer header visible
      expect(result.length, 1);
      expect(result[0].entry.id, 'outer');
    });

    test('collapsing inner hides only its children', () {
      final entries = [
        _makeEntry(id: 'outer', groupId: 'outer', message: 'Outer'),
        _makeEntry(id: 'inner', groupId: 'inner', message: 'Inner'),
        _makeEntry(id: 'a', groupId: 'inner', message: 'deep'),
        _makeEntry(id: 'close-inner', groupId: 'inner', message: ''),
        _makeEntry(id: 'b', groupId: 'outer', message: 'sibling'),
        _makeEntry(id: 'close-outer', groupId: 'outer', message: ''),
      ];

      final result = processGrouping(
        entries: entries,
        textFilter: null,
        collapsedGroups: {'inner'},
      );

      // Outer header + inner header + sibling visible, deep hidden
      expect(result.length, 3);
      expect(result[0].entry.id, 'outer');
      expect(result[1].entry.id, 'inner');
      expect(result[2].entry.id, 'b');
    });

    test('entries without group have zero depth', () {
      final entries = [
        _makeEntry(id: 'grp1', groupId: 'grp1', message: 'Group'),
        _makeEntry(id: 'a', groupId: 'grp1', message: 'child'),
        _makeEntry(id: 'close1', groupId: 'grp1', message: ''),
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

  group('autoCollapseGroups', () {
    test('adds group with _collapsed label to collapsedGroups', () {
      final entries = [
        _makeEntry(
          id: 'grp1',
          groupId: 'grp1',
          message: 'Collapsed Group',
          labels: {'_collapsed': 'true'},
        ),
        _makeEntry(id: 'a', groupId: 'grp1', message: 'child'),
      ];

      final collapsed = <String>{};
      final seen = <String>{};
      autoCollapseGroups(
        entries: entries,
        collapsedGroups: collapsed,
        seenGroupIds: seen,
      );

      expect(collapsed, contains('grp1'));
      expect(seen, contains('grp1'));
    });

    test('does not add group without _collapsed label', () {
      final entries = [
        _makeEntry(id: 'grp1', groupId: 'grp1', message: 'Open Group'),
        _makeEntry(id: 'a', groupId: 'grp1', message: 'child'),
      ];

      final collapsed = <String>{};
      final seen = <String>{};
      autoCollapseGroups(
        entries: entries,
        collapsedGroups: collapsed,
        seenGroupIds: seen,
      );

      expect(collapsed, isEmpty);
      expect(seen, contains('grp1'));
    });

    test('does not re-collapse after group was already seen', () {
      final entries = [
        _makeEntry(
          id: 'grp1',
          groupId: 'grp1',
          message: 'Group',
          labels: {'_collapsed': 'true'},
        ),
      ];

      final collapsed = <String>{};
      final seen = <String>{'grp1'}; // already seen

      autoCollapseGroups(
        entries: entries,
        collapsedGroups: collapsed,
        seenGroupIds: seen,
      );

      expect(collapsed, isEmpty); // not re-added
    });

    test('handles multiple groups with mixed labels', () {
      final entries = [
        _makeEntry(
          id: 'grp1',
          groupId: 'grp1',
          message: 'Collapsed',
          labels: {'_collapsed': 'true'},
        ),
        _makeEntry(id: 'grp2', groupId: 'grp2', message: 'Open'),
        _makeEntry(
          id: 'grp3',
          groupId: 'grp3',
          message: 'Also Collapsed',
          labels: {'_collapsed': 'true'},
        ),
      ];

      final collapsed = <String>{};
      final seen = <String>{};
      autoCollapseGroups(
        entries: entries,
        collapsedGroups: collapsed,
        seenGroupIds: seen,
      );

      expect(collapsed, {'grp1', 'grp3'});
      expect(seen, {'grp1', 'grp2', 'grp3'});
    });

    test('ignores non-header entries', () {
      final entries = [
        _makeEntry(
          id: 'a',
          groupId: 'grp1',
          message: 'child with label',
          labels: {'_collapsed': 'true'},
        ),
      ];

      final collapsed = <String>{};
      final seen = <String>{};
      autoCollapseGroups(
        entries: entries,
        collapsedGroups: collapsed,
        seenGroupIds: seen,
      );

      expect(collapsed, isEmpty);
      expect(seen, isEmpty);
    });

    test('integrates with processGrouping to hide children', () {
      final entries = [
        _makeEntry(
          id: 'grp1',
          groupId: 'grp1',
          message: 'Auto-collapsed',
          labels: {'_collapsed': 'true'},
        ),
        _makeEntry(id: 'a', groupId: 'grp1', message: 'hidden child'),
        _makeEntry(id: 'b', message: 'visible'),
      ];

      final collapsed = <String>{};
      final seen = <String>{};
      autoCollapseGroups(
        entries: entries,
        collapsedGroups: collapsed,
        seenGroupIds: seen,
      );

      final result = processGrouping(
        entries: entries,
        textFilter: null,
        collapsedGroups: collapsed,
      );

      expect(result.length, 2);
      expect(result[0].entry.id, 'grp1');
      expect(result[1].entry.id, 'b');
    });
  });
}
