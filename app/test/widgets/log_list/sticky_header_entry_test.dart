import 'package:app/services/session_store.dart';
import 'package:app/theme/theme.dart';
import 'package:app/widgets/log_list/sticky_group_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../test_helpers.dart';

Widget _wrapWidget(Widget child) {
  return ChangeNotifierProvider(
    create: (_) => SessionStore(),
    child: MaterialApp(
      theme: createLoggerTheme(),
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  group('StickyGroupHeader', () {
    testWidgets('renders group label', (tester) async {
      final entry = makeTestEntry(groupId: 'g1', message: 'My Group');

      await tester.pumpWidget(
        _wrapWidget(StickyGroupHeader(entry: entry, depth: 0)),
      );

      expect(find.text('My Group'), findsOneWidget);
      expect(find.text('PINNED'), findsOneWidget);
    });

    testWidgets('falls back to groupId when label is null', (tester) async {
      final entry = makeTestEntry(groupId: 'fallback-id');

      await tester.pumpWidget(
        _wrapWidget(StickyGroupHeader(entry: entry, depth: 0)),
      );

      expect(find.text('fallback-id'), findsOneWidget);
    });
  });

  group('StickyEntryRow', () {
    testWidgets('renders entry content', (tester) async {
      final entry = makeTestEntry(message: 'sticky line');

      await tester.pumpWidget(
        _wrapWidget(
          SizedBox(height: 40, child: StickyEntryRow(entry: entry, depth: 0)),
        ),
      );

      expect(find.byType(StickyEntryRow), findsOneWidget);
    });
  });

  group('HiddenItemsBadge', () {
    testWidgets('renders count text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: createLoggerTheme(),
          home: const Scaffold(body: HiddenItemsBadge(count: 5)),
        ),
      );

      expect(find.text('5 items hidden'), findsOneWidget);
    });

    testWidgets('renders singular form for count 1', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: createLoggerTheme(),
          home: const Scaffold(body: HiddenItemsBadge(count: 1)),
        ),
      );

      expect(find.text('1 item hidden'), findsOneWidget);
    });

    testWidgets('calls onTap with groupId', (tester) async {
      String? tappedGroup;

      await tester.pumpWidget(
        MaterialApp(
          theme: createLoggerTheme(),
          home: Scaffold(
            body: HiddenItemsBadge(
              count: 3,
              groupId: 'g1',
              onTap: (id) => tappedGroup = id,
            ),
          ),
        ),
      );

      await tester.tap(find.text('3 items hidden'));
      expect(tappedGroup, 'g1');
    });
  });

  group('StickyCloseButton', () {
    testWidgets('shows close icon by default', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: createLoggerTheme(),
          home: const Scaffold(body: StickyCloseButton()),
        ),
      );

      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('shows visibility_off icon when alt pressed', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: createLoggerTheme(),
          home: const Scaffold(body: StickyCloseButton(altPressed: true)),
        ),
      );

      expect(find.byIcon(Icons.visibility_off), findsOneWidget);
    });

    testWidgets('calls onTap callback', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: createLoggerTheme(),
          home: Scaffold(body: StickyCloseButton(onTap: () => tapped = true)),
        ),
      );

      await tester.tap(find.byIcon(Icons.close));
      expect(tapped, isTrue);
    });
  });
}
