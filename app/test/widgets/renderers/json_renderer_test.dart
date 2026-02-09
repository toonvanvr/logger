import 'package:app/models/log_entry.dart';
import 'package:app/services/session_store.dart';
import 'package:app/theme/theme.dart';
import 'package:app/widgets/renderers/json_renderer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../test_helpers.dart';

LogEntry _makeJsonEntry({required dynamic jsonData}) {
  return makeTestEntry(
    kind: EntryKind.event,
    widget: WidgetPayload(type: 'json', data: {'data': jsonData}),
  );
}

Widget _wrap(Widget child) {
  return MultiProvider(
    providers: [ChangeNotifierProvider(create: (_) => SessionStore())],
    child: MaterialApp(
      theme: createLoggerTheme(),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

void main() {
  testWidgets('renders collapsed by default', (tester) async {
    await tester.pumpWidget(
      _wrap(
        JsonRenderer(
          entry: _makeJsonEntry(jsonData: {'name': 'test', 'count': 42}),
        ),
      ),
    );

    // Should show collapsed indicator with count.
    expect(find.textContaining('{…}'), findsOneWidget);
    expect(find.textContaining('(2)'), findsOneWidget);
  });

  testWidgets('expands on tap', (tester) async {
    await tester.pumpWidget(
      _wrap(JsonRenderer(entry: _makeJsonEntry(jsonData: {'name': 'test'}))),
    );

    // Initially collapsed.
    expect(find.textContaining('{…}'), findsOneWidget);

    // Tap to expand.
    await tester.tap(find.textContaining('{…}'));
    await tester.pumpAndSettle();

    // After expanding, we should see the key.
    expect(find.textContaining('"name"'), findsOneWidget);
  });

  testWidgets('shows key-value pairs with colors', (tester) async {
    await tester.pumpWidget(
      _wrap(
        JsonRenderer(
          entry: _makeJsonEntry(
            jsonData: {'str': 'hello', 'num': 42, 'bool': true, 'nil': null},
          ),
        ),
      ),
    );

    // Expand.
    await tester.tap(find.textContaining('{…}'));
    await tester.pumpAndSettle();

    // Check key-value pairs are rendered.
    expect(find.textContaining('"str"'), findsOneWidget);
    expect(find.textContaining('"hello"'), findsOneWidget);
    expect(find.textContaining('42'), findsWidgets);
    expect(find.textContaining('true'), findsWidgets);
    expect(find.textContaining('null'), findsWidgets);
  });
}
