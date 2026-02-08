import 'package:app/theme/theme.dart';
import 'package:app/widgets/header/search_suggestions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: createLoggerTheme(),
    home: Scaffold(body: child),
  );
}

void main() {
  group('SearchSuggestions scrollbar behaviour', () {
    testWidgets('single item uses NeverScrollableScrollPhysics', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          SearchSuggestions(
            suggestions: const ['uuid:'],
            onSelected: (_) {},
            onDismiss: () {},
            maxVisible: 8,
          ),
        ),
      );

      // Find the ListView inside SearchSuggestions.
      final listView = tester.widget<ListView>(find.byType(ListView));
      expect(listView.physics, isA<NeverScrollableScrollPhysics>());
    });

    testWidgets('items equal to maxVisible uses NeverScrollableScrollPhysics', (
      tester,
    ) async {
      final items = List.generate(3, (i) => 'item-$i');

      await tester.pumpWidget(
        _wrap(
          SearchSuggestions(
            suggestions: items,
            onSelected: (_) {},
            onDismiss: () {},
            maxVisible: 3,
          ),
        ),
      );

      final listView = tester.widget<ListView>(find.byType(ListView));
      expect(listView.physics, isA<NeverScrollableScrollPhysics>());
    });

    testWidgets('more items than maxVisible allows scrolling', (tester) async {
      final items = List.generate(10, (i) => 'item-$i');

      await tester.pumpWidget(
        _wrap(
          SearchSuggestions(
            suggestions: items,
            onSelected: (_) {},
            onDismiss: () {},
            maxVisible: 5,
          ),
        ),
      );

      final listView = tester.widget<ListView>(find.byType(ListView));
      // Default physics when scrolling is needed — should not be
      // NeverScrollableScrollPhysics.
      expect(listView.physics, isNull);
    });
  });
}
