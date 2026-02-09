import 'package:app/models/log_entry.dart';
import 'package:app/theme/theme.dart';
import 'package:app/widgets/renderers/group_renderer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers.dart';

LogEntry _makeGroupEntry({String? label}) {
  return makeTestEntry(kind: EntryKind.event, groupId: 'g1', message: label);
}

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: createLoggerTheme(),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  group('GroupRenderer', () {
    // ── Test 1: group header shows label with chevron ──

    testWidgets('group header shows label with expand icon', (tester) async {
      await tester.pumpWidget(
        _wrap(GroupRenderer(entry: _makeGroupEntry(label: 'Network'))),
      );

      expect(find.text('Network'), findsOneWidget);
      expect(find.byIcon(Icons.expand_more), findsOneWidget);
    });

    // ── Test 2: group header without label shows groupId ──

    testWidgets('group header without label shows groupId', (tester) async {
      await tester.pumpWidget(_wrap(GroupRenderer(entry: _makeGroupEntry())));

      expect(find.text('g1'), findsOneWidget);
    });
  });
}
