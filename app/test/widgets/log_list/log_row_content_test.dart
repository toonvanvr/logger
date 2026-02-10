import 'package:app/models/log_entry.dart';
import 'package:app/theme/theme.dart';
import 'package:app/widgets/log_list/log_row_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers.dart';

void main() {
  group('serializeLogEntry', () {
    test('returns message for event entry', () {
      final entry = makeTestEntry(message: 'hello world');
      expect(serializeLogEntry(entry), 'hello world');
    });

    test('returns formatted JSON for json widget entry', () {
      final entry = makeTestEntry(
        kind: EntryKind.event,
        widget: WidgetPayload(
          type: 'json',
          data: {
            'data': {'key': 'value'},
          },
        ),
      );
      expect(serializeLogEntry(entry), contains('"key": "value"'));
    });

    test('returns message + JSON when both present', () {
      final entry = makeTestEntry(
        kind: EntryKind.event,
        message: 'prefix',
        widget: WidgetPayload(
          type: 'json',
          data: {
            'data': {'a': 1},
          },
        ),
      );
      final result = serializeLogEntry(entry);
      expect(result, startsWith('prefix'));
      expect(result, contains('"a": 1'));
    });

    test('returns group label for group header entry', () {
      final entry = makeTestEntry(groupId: 'g1', message: 'My Group');
      expect(serializeLogEntry(entry), 'My Group');
    });

    test('returns empty string for entry with no message', () {
      final entry = makeTestEntry(message: null);
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
              entry: makeTestEntry(message: 'log message here'),
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
              entry: makeTestEntry(id: 'g1', groupId: 'g1', message: 'HTTP'),
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
                id: 'g2',
                groupId: 'g2',
                message: 'Collapsed',
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
              entry: makeTestEntry(message: 'nested'),
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

  group('Duration badge', () {
    testWidgets('renders duration badge for group with _duration_ms', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: createLoggerTheme(),
          home: Scaffold(
            body: LogRowContent(
              entry: makeTestEntry(
                id: 'g1',
                groupId: 'g1',
                message: 'HTTP Request',
                labels: {'_duration_ms': '45'},
              ),
            ),
          ),
        ),
      );

      expect(find.text('45ms'), findsOneWidget);
    });

    testWidgets('does not render badge without _duration_ms', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: createLoggerTheme(),
          home: Scaffold(
            body: LogRowContent(
              entry: makeTestEntry(id: 'g1', groupId: 'g1', message: 'Group'),
            ),
          ),
        ),
      );

      // No duration text should be found
      expect(find.textContaining('ms'), findsNothing);
      expect(find.textContaining('s'), findsNothing);
    });

    testWidgets('formats seconds for >= 1000ms', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: createLoggerTheme(),
          home: Scaffold(
            body: LogRowContent(
              entry: makeTestEntry(
                id: 'g1',
                groupId: 'g1',
                message: 'Slow',
                labels: {'_duration_ms': '2500'},
              ),
            ),
          ),
        ),
      );

      expect(find.text('2.5s'), findsOneWidget);
    });

    testWidgets('green color for duration < 100ms', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: createLoggerTheme(),
          home: Scaffold(
            body: LogRowContent(
              entry: makeTestEntry(
                id: 'g1',
                groupId: 'g1',
                message: 'Fast',
                labels: {'_duration_ms': '50'},
              ),
            ),
          ),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container).last);
      final decoration = container.decoration as BoxDecoration;
      // Green at 15% alpha
      expect(decoration.color, const Color(0xFFA8CC7E).withAlpha(38));
    });

    testWidgets('amber color for duration 100-499ms', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: createLoggerTheme(),
          home: Scaffold(
            body: LogRowContent(
              entry: makeTestEntry(
                id: 'g1',
                groupId: 'g1',
                message: 'Medium',
                labels: {'_duration_ms': '250'},
              ),
            ),
          ),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container).last);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, const Color(0xFFE6B455).withAlpha(38));
    });

    testWidgets('red color for duration >= 500ms', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: createLoggerTheme(),
          home: Scaffold(
            body: LogRowContent(
              entry: makeTestEntry(
                id: 'g1',
                groupId: 'g1',
                message: 'Slow',
                labels: {'_duration_ms': '750'},
              ),
            ),
          ),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container).last);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, const Color(0xFFE06C60).withAlpha(38));
    });
  });
}
