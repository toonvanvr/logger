import 'package:app/models/log_entry.dart';
import 'package:app/theme/theme.dart';
import 'package:app/widgets/log_list/log_row_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers.dart';

void main() {
  group('serializeLogEntry', () {
    test('returns text for text entry', () {
      final entry = makeTestEntry(text: 'hello world');
      expect(serializeLogEntry(entry), 'hello world');
    });

    test('returns formatted JSON for json entry', () {
      final entry = makeTestEntry(
        type: LogType.json,
        jsonData: {'key': 'value'},
      );
      expect(serializeLogEntry(entry), contains('"key": "value"'));
    });

    test('returns text + JSON when both present', () {
      final entry = makeTestEntry(
        type: LogType.json,
        text: 'prefix',
        jsonData: {'a': 1},
      );
      final result = serializeLogEntry(entry);
      expect(result, startsWith('prefix'));
      expect(result, contains('"a": 1'));
    });

    test('returns group label for group entry', () {
      final entry = makeTestEntry(
        type: LogType.group,
        groupAction: GroupAction.open,
        groupLabel: 'My Group',
        groupId: 'g1',
      );
      expect(serializeLogEntry(entry), 'My Group');
    });

    test('returns empty string for entry with no text', () {
      final entry = makeTestEntry(text: null);
      expect(serializeLogEntry(entry), '');
    });
  });

  group('LogRowContent', () {
    testWidgets('renders text entry content', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: createLoggerTheme(),
          home: Scaffold(
            body: LogRowContent(
              entry: makeTestEntry(text: 'log message here'),
            ),
          ),
        ),
      );

      expect(
        find.byWidgetPredicate(
          (w) =>
              w is RichText &&
              w.text.toPlainText().contains('log message here'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders group open with collapse icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: createLoggerTheme(),
          home: Scaffold(
            body: LogRowContent(
              entry: makeTestEntry(
                type: LogType.group,
                groupAction: GroupAction.open,
                groupLabel: 'HTTP',
                groupId: 'g1',
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.expand_more), findsOneWidget);
      expect(find.text('HTTP'), findsOneWidget);
    });

    testWidgets('collapsed group shows chevron_right', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: createLoggerTheme(),
          home: Scaffold(
            body: LogRowContent(
              entry: makeTestEntry(
                type: LogType.group,
                groupAction: GroupAction.open,
                groupLabel: 'Collapsed',
                groupId: 'g2',
              ),
              isCollapsed: true,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('group depth adds left padding', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: createLoggerTheme(),
          home: Scaffold(
            body: LogRowContent(
              entry: makeTestEntry(text: 'nested'),
              groupDepth: 2,
            ),
          ),
        ),
      );

      // Depth > 0 wraps in a Padding with left indent
      final padding = tester.widget<Padding>(find.byType(Padding).first);
      expect(padding.padding, isNotNull);
    });
  });
}
