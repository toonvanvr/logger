import 'package:app/models/log_entry.dart';
import 'package:app/theme/theme.dart';
import 'package:app/widgets/renderers/group_renderer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers.dart';

LogEntry _makeGroupEntry({
  GroupAction action = GroupAction.open,
  String? label,
  bool collapsed = false,
}) {
  return makeTestEntry(
    type: LogType.group,
    groupId: 'g1',
    groupAction: action,
    groupLabel: label,
    groupCollapsed: collapsed,
  );
}

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: createLoggerTheme(),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  group('GroupRenderer', () {
    // ── Test 1: open action shows label with chevron ──

    testWidgets('open action shows label with expand icon', (tester) async {
      await tester.pumpWidget(
        _wrap(
          GroupRenderer(
            entry: _makeGroupEntry(action: GroupAction.open, label: 'Network'),
          ),
        ),
      );

      expect(find.text('Network'), findsOneWidget);
      expect(find.byIcon(Icons.expand_more), findsOneWidget);
    });

    // ── Test 2: close action shows End: text ──

    testWidgets('close action shows End: label', (tester) async {
      await tester.pumpWidget(
        _wrap(
          GroupRenderer(
            entry: _makeGroupEntry(action: GroupAction.close, label: 'Network'),
          ),
        ),
      );

      expect(find.text('End: Network'), findsOneWidget);
    });
  });
}
