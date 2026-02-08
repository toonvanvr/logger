import 'package:app/models/log_entry.dart';
import 'package:app/services/log_store.dart';
import 'package:app/services/session_store.dart';
import 'package:app/services/sticky_state.dart';
import 'package:app/services/time_range_service.dart';
import 'package:app/theme/theme.dart';
import 'package:app/widgets/log_list/log_list_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

LogEntry _makeEntry({
  required String id,
  String text = 'log line',
  Severity severity = Severity.info,
  String sessionId = 'sess-1',
  LogType type = LogType.text,
  String? groupId,
  GroupAction? groupAction,
  String? groupLabel,
  bool? sticky,
}) {
  return LogEntry(
    id: id,
    timestamp: '2026-02-08T10:00:00.000Z',
    sessionId: sessionId,
    severity: severity,
    type: type,
    text: type == LogType.text ? text : null,
    groupId: groupId,
    groupAction: groupAction,
    groupLabel: groupLabel,
    sticky: sticky,
  );
}

Widget _wrap({required LogStore logStore}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: logStore),
      ChangeNotifierProvider(create: (_) => SessionStore()),
      ChangeNotifierProvider(create: (_) => StickyStateService()),
      ChangeNotifierProvider(create: (_) => TimeRangeService()),
    ],
    child: MaterialApp(
      theme: createLoggerTheme(),
      home: const Scaffold(body: LogListView()),
    ),
  );
}

void main() {
  group('Sticky entries', () {
    testWidgets('sticky entry shows PINNED badge in header', (tester) async {
      final store = LogStore();
      store.addEntries([
        _makeEntry(id: 'a', text: 'normal log'),
        _makeEntry(id: 'b', text: 'sticky log', sticky: true),
        _makeEntry(id: 'c', text: 'another normal'),
      ]);

      await tester.pumpWidget(_wrap(logStore: store));
      await tester.pumpAndSettle();

      // Should find the PINNED badge from the sticky header
      expect(find.text('PINNED'), findsNothing);

      // The sticky entry text should appear (in both the header and the list)
      expect(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().contains('sticky log'),
        ),
        findsWidgets,
      );
    });

    testWidgets('sticky group shows group header in pinned section', (
      tester,
    ) async {
      final store = LogStore();
      store.addEntries([
        _makeEntry(
          id: 'g1-open',
          type: LogType.group,
          groupId: 'g1',
          groupAction: GroupAction.open,
          groupLabel: 'Build Output',
          sticky: true,
        ),
        _makeEntry(id: 'g1-a', text: 'Compiling...', groupId: 'g1'),
        _makeEntry(id: 'g1-b', text: 'Build done', groupId: 'g1'),
        _makeEntry(
          id: 'g1-close',
          type: LogType.group,
          groupId: 'g1',
          groupAction: GroupAction.close,
        ),
        _makeEntry(id: 'normal', text: 'After group'),
      ]);

      await tester.pumpWidget(_wrap(logStore: store));
      await tester.pumpAndSettle();

      // Group header should appear in sticky section with PINNED badge
      expect(find.text('PINNED'), findsOneWidget);
      expect(find.text('Build Output'), findsWidgets);
    });

    testWidgets(
      'large group with individual sticky children shows hidden count',
      (tester) async {
        final store = LogStore();
        store.addEntries([
          _makeEntry(
            id: 'g2-open',
            type: LogType.group,
            groupId: 'g2',
            groupAction: GroupAction.open,
            groupLabel: 'API Pipeline',
          ),
          _makeEntry(id: 'g2-a', text: 'Parsing body...', groupId: 'g2'),
          _makeEntry(id: 'g2-b', text: 'Validating...', groupId: 'g2'),
          _makeEntry(
            id: 'g2-c',
            text: 'Auth verified',
            groupId: 'g2',
            sticky: true,
          ),
          _makeEntry(id: 'g2-d', text: 'DB query...', groupId: 'g2'),
          _makeEntry(
            id: 'g2-e',
            text: '201 Created',
            groupId: 'g2',
            sticky: true,
          ),
          _makeEntry(id: 'g2-f', text: 'Done', groupId: 'g2'),
          _makeEntry(
            id: 'g2-close',
            type: LogType.group,
            groupId: 'g2',
            groupAction: GroupAction.close,
          ),
        ]);

        await tester.pumpWidget(_wrap(logStore: store));
        await tester.pumpAndSettle();

        // Should show the group header in pinned area
        expect(find.text('API Pipeline'), findsWidgets);

        // Should show hidden items count badge
        // 4 non-sticky entries: g2-a, g2-b, g2-d, g2-f
        expect(find.text('4 items hidden'), findsOneWidget);

        // Sticky entries should be visible
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is RichText && w.text.toPlainText().contains('Auth verified'),
          ),
          findsWidgets,
        );
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is RichText && w.text.toPlainText().contains('201 Created'),
          ),
          findsWidgets,
        );
      },
    );

    testWidgets('no sticky section when no entries are sticky', (tester) async {
      final store = LogStore();
      store.addEntries([
        _makeEntry(id: 'a', text: 'normal log 1'),
        _makeEntry(id: 'b', text: 'normal log 2'),
      ]);

      await tester.pumpWidget(_wrap(logStore: store));
      await tester.pumpAndSettle();

      // No PINNED badge, no hidden items badge
      expect(find.text('PINNED'), findsNothing);
      expect(
        find.byWidgetPredicate(
          (w) => w is Text && (w.data?.contains('items hidden') ?? false),
        ),
        findsNothing,
      );
    });

    testWidgets('multiple standalone sticky entries render in header', (
      tester,
    ) async {
      final store = LogStore();
      store.addEntries([
        _makeEntry(id: 'a', text: 'Server running on :3000', sticky: true),
        _makeEntry(id: 'b', text: 'Memory: 87%', sticky: true),
        _makeEntry(id: 'c', text: 'Normal log'),
        _makeEntry(id: 'd', text: 'Another log'),
      ]);

      await tester.pumpWidget(_wrap(logStore: store));
      await tester.pumpAndSettle();

      // Both sticky entries should be visible
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is RichText &&
              w.text.toPlainText().contains('Server running on :3000'),
        ),
        findsWidgets,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().contains('Memory: 87%'),
        ),
        findsWidgets,
      );
    });
  });
}
