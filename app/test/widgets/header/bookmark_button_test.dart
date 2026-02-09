import 'package:app/services/query_store.dart';
import 'package:app/theme/theme.dart';
import 'package:app/widgets/header/bookmark_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

Widget _wrap({required QueryStore queryStore}) {
  return ChangeNotifierProvider.value(
    value: queryStore,
    child: MaterialApp(
      theme: createLoggerTheme(),
      home: Scaffold(
        body: BookmarkButton(
          activeSeverities: const {'info', 'error'},
          textFilter: '',
          onQueryLoaded: (_) {},
        ),
      ),
    ),
  );
}

void main() {
  group('BookmarkButton', () {
    testWidgets('renders bookmark_border icon when no saved queries', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(queryStore: QueryStore()));

      expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
    });

    testWidgets('renders bookmark icon when queries exist', (tester) async {
      final store = QueryStore();
      store.saveQuery('test', severities: {'info'}, textFilter: '');

      await tester.pumpWidget(_wrap(queryStore: store));

      expect(find.byIcon(Icons.bookmark), findsOneWidget);
    });

    testWidgets('shows save option in popup menu', (tester) async {
      await tester.pumpWidget(_wrap(queryStore: QueryStore()));

      // Open popup
      await tester.tap(find.byIcon(Icons.bookmark_border));
      await tester.pumpAndSettle();

      expect(find.text('Save current filters'), findsOneWidget);
    });

    testWidgets('shows saved queries in popup menu', (tester) async {
      final store = QueryStore();
      store.saveQuery('My Filter', severities: {'info'}, textFilter: 'foo');

      await tester.pumpWidget(_wrap(queryStore: store));

      await tester.tap(find.byIcon(Icons.bookmark));
      await tester.pumpAndSettle();

      expect(find.text('My Filter'), findsOneWidget);
    });

    testWidgets('save action opens dialog', (tester) async {
      await tester.pumpWidget(_wrap(queryStore: QueryStore()));

      await tester.tap(find.byIcon(Icons.bookmark_border));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save current filters'));
      await tester.pumpAndSettle();

      expect(find.text('Save Query'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });
  });
}
