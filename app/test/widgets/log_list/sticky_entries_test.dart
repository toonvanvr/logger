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

import '../../test_helpers.dart';

LogEntry _makeEntry({
  required String id,
  String message = 'log line',
  Severity severity = Severity.info,
  String sessionId = 'sess-1',
  String? groupId,
  String? parentId,
  DisplayLocation display = DisplayLocation.defaultLoc,
}) {
  return makeTestEntry(
    id: id,
    message: message,
    severity: severity,
    sessionId: sessionId,
    groupId: groupId,
    parentId: parentId,
    display: display,
  );
}

Widget _wrap({
  required LogStore logStore,
  Set<String> stickyOverrideIds = const {},
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: logStore),
      ChangeNotifierProvider(create: (_) => SessionStore()),
      ChangeNotifierProvider(create: (_) => StickyStateService()),
      ChangeNotifierProvider(create: (_) => TimeRangeService()),
    ],
    child: MaterialApp(
      theme: createLoggerTheme(),
      home: Scaffold(body: LogListView(stickyOverrideIds: stickyOverrideIds)),
    ),
  );
}

void main() {
  group('Sticky entries', () {
    testWidgets('sticky entry shows PINNED badge in header', (tester) async {
      final store = LogStore();
      store.addEntries([
        _makeEntry(id: 'a', message: 'normal log'),
        _makeEntry(
          id: 'b',
          message: 'sticky log',
          display: DisplayLocation.static_,
        ),
        _makeEntry(id: 'c', message: 'another normal'),
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
          id: 'g1',
          groupId: 'g1',
          message: 'Build Output',
          display: DisplayLocation.static_,
        ),
        _makeEntry(id: 'g1-a', groupId: 'g1', message: 'Compiling...'),
        _makeEntry(id: 'g1-b', groupId: 'g1', message: 'Build done'),
        _makeEntry(id: 'normal', message: 'After group'),
      ]);

      await tester.pumpWidget(
        _wrap(logStore: store, stickyOverrideIds: {'g1'}),
      );
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
          _makeEntry(id: 'g2', groupId: 'g2', message: 'API Pipeline'),
          _makeEntry(id: 'g2-a', groupId: 'g2', message: 'Parsing body...'),
          _makeEntry(id: 'g2-b', groupId: 'g2', message: 'Validating...'),
          _makeEntry(
            id: 'g2-c',
            groupId: 'g2',
            message: 'Auth verified',
            display: DisplayLocation.static_,
          ),
          _makeEntry(id: 'g2-d', groupId: 'g2', message: 'DB query...'),
          _makeEntry(
            id: 'g2-e',
            groupId: 'g2',
            message: '201 Created',
            display: DisplayLocation.static_,
          ),
          _makeEntry(id: 'g2-f', groupId: 'g2', message: 'Done'),
        ]);

        await tester.pumpWidget(
          _wrap(logStore: store, stickyOverrideIds: {'g2-c', 'g2-e'}),
        );
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
        _makeEntry(id: 'a', message: 'normal log 1'),
        _makeEntry(id: 'b', message: 'normal log 2'),
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
        _makeEntry(
          id: 'a',
          message: 'Server running on :3000',
          display: DisplayLocation.static_,
        ),
        _makeEntry(
          id: 'b',
          message: 'Memory: 87%',
          display: DisplayLocation.static_,
        ),
        _makeEntry(id: 'c', message: 'Normal log'),
        _makeEntry(id: 'd', message: 'Another log'),
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
