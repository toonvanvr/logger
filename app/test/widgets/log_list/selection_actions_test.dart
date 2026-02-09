import 'package:app/theme/theme.dart';
import 'package:app/widgets/log_list/selection_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SelectionActions', () {
    Widget buildActions({
      int count = 3,
      VoidCallback? onCopy,
      VoidCallback? onExportJson,
      VoidCallback? onBookmark,
      VoidCallback? onSticky,
      VoidCallback? onClear,
    }) {
      return MaterialApp(
        theme: createLoggerTheme(),
        home: Scaffold(
          body: SelectionActions(
            selectedCount: count,
            onCopy: onCopy ?? () {},
            onExportJson: onExportJson ?? () {},
            onBookmark: onBookmark ?? () {},
            onSticky: onSticky ?? () {},
            onClear: onClear ?? () {},
          ),
        ),
      );
    }

    testWidgets('renders all action buttons', (tester) async {
      await tester.pumpWidget(buildActions());

      expect(find.byIcon(Icons.content_copy), findsOneWidget);
      expect(find.byIcon(Icons.data_object), findsOneWidget);
      expect(find.byIcon(Icons.bookmark_outline), findsOneWidget);
      expect(find.byIcon(Icons.push_pin_outlined), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('displays selected count badge', (tester) async {
      await tester.pumpWidget(buildActions(count: 7));

      expect(find.text('7'), findsOneWidget);
    });

    testWidgets('copy callback fires on tap', (tester) async {
      var copied = false;
      await tester.pumpWidget(buildActions(onCopy: () => copied = true));

      await tester.tap(find.byIcon(Icons.content_copy));
      expect(copied, isTrue);
    });

    testWidgets('export JSON callback fires on tap', (tester) async {
      var exported = false;
      await tester.pumpWidget(
        buildActions(onExportJson: () => exported = true),
      );

      await tester.tap(find.byIcon(Icons.data_object));
      expect(exported, isTrue);
    });

    testWidgets('clear callback fires on tap', (tester) async {
      var cleared = false;
      await tester.pumpWidget(buildActions(onClear: () => cleared = true));

      await tester.tap(find.byIcon(Icons.close));
      expect(cleared, isTrue);
    });

    testWidgets('bookmark callback fires on tap', (tester) async {
      var bookmarked = false;
      await tester.pumpWidget(
        buildActions(onBookmark: () => bookmarked = true),
      );

      await tester.tap(find.byIcon(Icons.bookmark_outline));
      expect(bookmarked, isTrue);
    });
  });
}
