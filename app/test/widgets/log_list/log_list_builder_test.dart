import 'package:app/models/log_entry.dart';
import 'package:app/widgets/log_list/log_list_builder.dart';
import 'package:flutter_test/flutter_test.dart';

LogEntry _makeEntry({
  required String id,
  Severity severity = Severity.info,
  LogType type = LogType.text,
  String? text,
  bool? sticky,
  String? groupId,
  GroupAction? groupAction,
  String? groupLabel,
}) {
  return LogEntry(
    id: id,
    timestamp: '2026-02-08T00:00:00Z',
    sessionId: 's1',
    severity: severity,
    type: type,
    text: text,
    sticky: sticky,
    groupId: groupId,
    groupAction: groupAction,
    groupLabel: groupLabel,
  );
}

void main() {
  group('processGrouping stickyOverrideIds', () {
    test('marks entries in stickyOverrideIds as sticky', () {
      final entries = [
        _makeEntry(id: 'a', text: 'first'),
        _makeEntry(id: 'b', text: 'second'),
        _makeEntry(id: 'c', text: 'third'),
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

    test('combines protocol sticky with override sticky', () {
      final entries = [
        _makeEntry(id: 'a', text: 'protocol sticky', sticky: true),
        _makeEntry(id: 'b', text: 'override sticky'),
        _makeEntry(id: 'c', text: 'not sticky'),
      ];

      final result = processGrouping(
        entries: entries,
        textFilter: null,
        collapsedGroups: {},
        stickyOverrideIds: {'b'},
      );

      expect(result[0].isSticky, true); // protocol
      expect(result[1].isSticky, true); // override
      expect(result[2].isSticky, false);
    });

    test('override on already-sticky entry is no-op', () {
      final entries = [_makeEntry(id: 'a', text: 'both', sticky: true)];

      final result = processGrouping(
        entries: entries,
        textFilter: null,
        collapsedGroups: {},
        stickyOverrideIds: {'a'},
      );

      expect(result[0].isSticky, true);
    });

    test('null stickyOverrideIds has no effect', () {
      final entries = [_makeEntry(id: 'a', text: 'normal')];

      final result = processGrouping(
        entries: entries,
        textFilter: null,
        collapsedGroups: {},
      );

      expect(result[0].isSticky, false);
    });

    test('empty stickyOverrideIds marks nothing as sticky', () {
      final entries = [_makeEntry(id: 'a', text: 'normal')];

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
    test('computes correct depth for nested groups', () {
      final entries = [
        _makeEntry(
          id: 'g1',
          type: LogType.group,
          groupAction: GroupAction.open,
          groupId: 'grp1',
          groupLabel: 'Outer',
        ),
        _makeEntry(id: 'a', text: 'inside outer'),
        _makeEntry(
          id: 'g1c',
          type: LogType.group,
          groupAction: GroupAction.close,
          groupId: 'grp1',
        ),
      ];

      final result = processGrouping(
        entries: entries,
        textFilter: null,
        collapsedGroups: {},
      );

      expect(result.length, 3);
      expect(result[0].depth, 0); // group open
      expect(result[1].depth, 1); // child
      expect(result[2].depth, 0); // group close
    });

    test('hides entries in collapsed groups', () {
      final entries = [
        _makeEntry(
          id: 'g1',
          type: LogType.group,
          groupAction: GroupAction.open,
          groupId: 'grp1',
          groupLabel: 'Group',
        ),
        _makeEntry(id: 'a', text: 'hidden child'),
        _makeEntry(
          id: 'g1c',
          type: LogType.group,
          groupAction: GroupAction.close,
          groupId: 'grp1',
        ),
      ];

      final result = processGrouping(
        entries: entries,
        textFilter: null,
        collapsedGroups: {'grp1'},
      );

      // Group open is visible, child and close are hidden
      expect(result.length, 1);
      expect(result[0].entry.id, 'g1');
    });
  });

  group('processGrouping auto-close orphaned groups', () {
    test('auto-closes single unclosed group', () {
      final entries = [
        _makeEntry(
          id: 'g1',
          type: LogType.group,
          groupAction: GroupAction.open,
          groupId: 'grp1',
          groupLabel: 'Orphan',
        ),
        _makeEntry(id: 'a', text: 'inside orphan'),
      ];

      final result = processGrouping(
        entries: entries,
        textFilter: null,
        collapsedGroups: {},
      );

      expect(result.length, 3);
      expect(result[0].entry.id, 'g1');
      expect(result[1].entry.id, 'a');
      // Synthetic auto-close entry
      final autoClose = result[2];
      expect(autoClose.entry.id, 'grp1_autoclose');
      expect(autoClose.entry.groupAction, GroupAction.close);
      expect(autoClose.entry.groupId, 'grp1');
      expect(autoClose.isAutoClose, true);
      expect(autoClose.depth, 0);
    });

    test('auto-closes multiple nested unclosed groups in reverse order', () {
      final entries = [
        _makeEntry(
          id: 'g1',
          type: LogType.group,
          groupAction: GroupAction.open,
          groupId: 'outer',
          groupLabel: 'Outer',
        ),
        _makeEntry(
          id: 'g2',
          type: LogType.group,
          groupAction: GroupAction.open,
          groupId: 'inner',
          groupLabel: 'Inner',
        ),
        _makeEntry(id: 'a', text: 'deep'),
      ];

      final result = processGrouping(
        entries: entries,
        textFilter: null,
        collapsedGroups: {},
      );

      expect(result.length, 5);
      // Inner auto-close first (reverse order)
      final innerClose = result[3];
      expect(innerClose.entry.groupId, 'inner');
      expect(innerClose.isAutoClose, true);
      expect(innerClose.depth, 1);
      expect(innerClose.parentGroupId, 'outer');
      // Outer auto-close second
      final outerClose = result[4];
      expect(outerClose.entry.groupId, 'outer');
      expect(outerClose.isAutoClose, true);
      expect(outerClose.depth, 0);
      expect(outerClose.parentGroupId, null);
    });

    test('only auto-closes unclosed groups in mixed scenario', () {
      final entries = [
        _makeEntry(
          id: 'g1',
          type: LogType.group,
          groupAction: GroupAction.open,
          groupId: 'closed_grp',
          groupLabel: 'Closed',
        ),
        _makeEntry(id: 'a', text: 'child of closed'),
        _makeEntry(
          id: 'g1c',
          type: LogType.group,
          groupAction: GroupAction.close,
          groupId: 'closed_grp',
        ),
        _makeEntry(
          id: 'g2',
          type: LogType.group,
          groupAction: GroupAction.open,
          groupId: 'orphan_grp',
          groupLabel: 'Orphan',
        ),
        _makeEntry(id: 'b', text: 'child of orphan'),
      ];

      final result = processGrouping(
        entries: entries,
        textFilter: null,
        collapsedGroups: {},
      );

      // 3 from closed group + 2 from orphan + 1 auto-close = 6
      expect(result.length, 6);
      final autoClose = result[5];
      expect(autoClose.entry.groupId, 'orphan_grp');
      expect(autoClose.isAutoClose, true);
      expect(autoClose.depth, 0);
      // Regular close entries are NOT auto-close
      final regularClose = result[2];
      expect(regularClose.isAutoClose, false);
    });

    test('no auto-close entries when all groups properly closed', () {
      final entries = [
        _makeEntry(
          id: 'g1',
          type: LogType.group,
          groupAction: GroupAction.open,
          groupId: 'grp1',
          groupLabel: 'Group',
        ),
        _makeEntry(id: 'a', text: 'child'),
        _makeEntry(
          id: 'g1c',
          type: LogType.group,
          groupAction: GroupAction.close,
          groupId: 'grp1',
        ),
      ];

      final result = processGrouping(
        entries: entries,
        textFilter: null,
        collapsedGroups: {},
      );

      expect(result.length, 3);
      for (final entry in result) {
        expect(entry.isAutoClose, false);
      }
    });
  });
}
