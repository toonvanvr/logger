import 'package:app/models/log_entry.dart';
import 'package:app/services/log_store.dart';
import 'package:app/services/session_store.dart';
import 'package:app/theme/theme.dart';
import 'package:app/widgets/log_list/live_pill.dart';
import 'package:app/widgets/log_list/log_list_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

LogEntry _makeEntry({
  required String id,
  String text = 'log line',
  Severity severity = Severity.info,
  String sessionId = 'sess-1',
}) {
  return LogEntry(
    id: id,
    timestamp: '2026-02-07T10:00:00.000Z',
    sessionId: sessionId,
    severity: severity,
    type: LogType.text,
    text: text,
  );
}

Widget _wrap({required LogStore logStore}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: logStore),
      ChangeNotifierProvider(create: (_) => SessionStore()),
    ],
    child: MaterialApp(
      theme: createLoggerTheme(),
      home: const Scaffold(body: LogListView()),
    ),
  );
}

void main() {
  testWidgets('renders empty state "Waiting for logs..."', (tester) async {
    final store = LogStore();
    await tester.pumpWidget(_wrap(logStore: store));

    expect(find.text('Waiting for logs...'), findsOneWidget);
  });

  testWidgets('renders list of log entries', (tester) async {
    final store = LogStore();
    store.addEntries([
      _makeEntry(id: 'a', text: 'first log'),
      _makeEntry(id: 'b', text: 'second log'),
      _makeEntry(id: 'c', text: 'third log'),
    ]);

    await tester.pumpWidget(_wrap(logStore: store));
    await tester.pumpAndSettle();

    // TextRenderer uses RichText, so match via predicate.
    expect(
      find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText().contains('first log'),
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText().contains('second log'),
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText().contains('third log'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('LIVE pill shows when at bottom', (tester) async {
    final store = LogStore();
    store.addEntry(_makeEntry(id: 'x', text: 'a log'));

    await tester.pumpWidget(_wrap(logStore: store));
    await tester.pumpAndSettle();

    // Should show LIVE pill since the list is scrolled to bottom.
    expect(find.byType(LivePill), findsOneWidget);
    expect(find.text('LIVE'), findsOneWidget);
  });
}
