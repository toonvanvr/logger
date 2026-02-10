import 'package:app/theme/theme.dart';
import 'package:app/widgets/log_list/section_tabs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: createLoggerTheme(),
    home: Scaffold(body: child),
  );
}

void main() {
  group('SectionTabs', () {
    // ── Test 1: hides tabs when only one section ──

    testWidgets('hides tabs when only one section', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SectionTabs(
            tags: const ['network'],
            selectedTag: null,
            onTagChanged: (_) {},
          ),
        ),
      );

      expect(find.text('ALL'), findsNothing);
      expect(find.byType(SizedBox), findsOneWidget);
    });

    // ── Test 1b: renders ALL tab with multiple sections ──

    testWidgets('renders ALL tab with multiple sections', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SectionTabs(
            tags: const ['network', 'metrics'],
            selectedTag: null,
            onTagChanged: (_) {},
          ),
        ),
      );

      expect(find.text('ALL'), findsOneWidget);
    });

    // ── Test 2: shows section tabs for custom sections ──

    testWidgets('shows section tabs for custom sections', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SectionTabs(
            tags: const ['network', 'ui'],
            selectedTag: null,
            onTagChanged: (_) {},
          ),
        ),
      );

      expect(find.text('ALL'), findsOneWidget);
      expect(find.text('NETWORK'), findsOneWidget);
      expect(find.text('UI'), findsOneWidget);
    });

    // ── Test 3: tap calls onSectionChanged ──

    testWidgets('tap calls onSectionChanged', (tester) async {
      String? selected;

      await tester.pumpWidget(
        _wrap(
          SectionTabs(
            tags: const ['network', 'ui'],
            selectedTag: null,
            onTagChanged: (s) => selected = s,
          ),
        ),
      );

      await tester.tap(find.text('NETWORK'));
      expect(selected, 'network');
    });
  });
}
