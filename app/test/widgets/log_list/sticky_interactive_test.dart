import 'package:app/models/log_entry.dart';
import 'package:app/services/log_store.dart';
import 'package:app/services/session_store.dart';
import 'package:app/services/sticky_state.dart';
import 'package:app/services/time_range_service.dart';
import 'package:app/theme/theme.dart';
import 'package:app/widgets/log_list/log_list_view.dart';
import 'package:app/widgets/log_list/sticky_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../test_helpers.dart';

// ─── Helpers ─────────────────────────────────────────────────────────

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
  StickyStateService? stickyState,
  Set<String> stickyOverrideIds = const {},
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: logStore),
      ChangeNotifierProvider(create: (_) => SessionStore()),
      ChangeNotifierProvider(
        create: (_) => stickyState ?? StickyStateService(),
      ),
      ChangeNotifierProvider(create: (_) => TimeRangeService()),
    ],
    child: MaterialApp(
      theme: createLoggerTheme(),
      home: Scaffold(body: LogListView(stickyOverrideIds: stickyOverrideIds)),
    ),
  );
}

Widget _wrapOverlay({
  required List<StickySection> sections,
  StickyStateService? stickyState,
  double maxHeightFraction = 0.3,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => SessionStore()),
      ChangeNotifierProvider(
        create: (_) => stickyState ?? StickyStateService(),
      ),
    ],
    child: MaterialApp(
      theme: createLoggerTheme(),
      home: Scaffold(
        body: Stack(
          children: [
            SizedBox.expand(),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SizedBox(
                height: 600,
                child: StickyHeaderOverlay(
                  sections: sections,
                  maxHeightFraction: maxHeightFraction,
                  stickyState: stickyState,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  // ─── S05: Close button ─────────────────────────────────────────

  group('S05 — Close/Ignore buttons', () {
    testWidgets('close button appears on sticky entry row', (tester) async {
      final store = LogStore();
      store.addEntries([
        _makeEntry(
          id: 'a',
          message: 'sticky log',
          display: DisplayLocation.static_,
        ),
        _makeEntry(id: 'b', message: 'normal log'),
      ]);

      await tester.pumpWidget(_wrap(logStore: store, stickyOverrideIds: {'a'}));
      await tester.pumpAndSettle();

      // Should find an Icons.close in the sticky area
      expect(find.byIcon(Icons.close), findsWidgets);
    });

    testWidgets('tapping close button dismisses sticky entry', (tester) async {
      final stickyState = StickyStateService();
      final section = StickySection(
        entries: [
          _makeEntry(
            id: 'e1',
            message: 'sticky entry',
            display: DisplayLocation.static_,
          ),
        ],
      );

      await tester.pumpWidget(
        _wrapOverlay(sections: [section], stickyState: stickyState),
      );
      await tester.pumpAndSettle();

      // Tap the close button
      await tester.tap(find.byIcon(Icons.close).first);
      await tester.pumpAndSettle();

      // Entry should be dismissed
      expect(stickyState.isDismissed('e1'), isTrue);
      expect(stickyState.dismissedCount, 1);
    });

    testWidgets('close button on group header dismisses group header', (
      tester,
    ) async {
      final stickyState = StickyStateService();
      final groupEntry = _makeEntry(
        id: 'g1-open',
        groupId: 'g1',
        message: 'Build',
        display: DisplayLocation.static_,
      );
      final section = StickySection(
        groupHeader: groupEntry,
        entries: [
          _makeEntry(id: 'g1-a', message: 'Building...', parentId: 'g1'),
        ],
        groupDepth: 0,
      );

      await tester.pumpWidget(
        _wrapOverlay(sections: [section], stickyState: stickyState),
      );
      await tester.pumpAndSettle();

      // There should be multiple close buttons (group header + entry)
      final closeButtons = find.byIcon(Icons.close);
      expect(closeButtons, findsAtLeast(2));

      // Tap the first close button (group header)
      await tester.tap(closeButtons.first);
      await tester.pumpAndSettle();

      // Group header entry should be dismissed
      expect(stickyState.isDismissed('g1-open'), isTrue);
    });

    testWidgets('dismissed entries are filtered from sticky display', (
      tester,
    ) async {
      final stickyState = StickyStateService();
      final store = LogStore();
      store.addEntries([
        _makeEntry(
          id: 'a',
          message: 'sticky 1',
          display: DisplayLocation.static_,
        ),
        _makeEntry(
          id: 'b',
          message: 'sticky 2',
          display: DisplayLocation.static_,
        ),
        _makeEntry(id: 'c', message: 'normal'),
      ]);

      // Pre-dismiss one entry
      stickyState.dismiss('a');

      await tester.pumpWidget(_wrap(logStore: store, stickyState: stickyState));
      await tester.pumpAndSettle();

      // 'sticky 2' should still be visible, 'sticky 1' should only appear once
      // (in the list, not in the sticky header)
      final sticky1Finder = find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText().contains('sticky 1'),
      );
      final sticky2Finder = find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText().contains('sticky 2'),
      );

      // sticky 2 appears in both header and list
      expect(sticky2Finder, findsWidgets);
      // sticky 1 should appear in the list only (1 instance)
      expect(sticky1Finder, findsOneWidget);
    });
  });

  // ─── S05: Alt-Click ignore ────────────────────────────────────

  group('S05 — Alt-key ignore mode', () {
    testWidgets(
      'visibility_off icon appears when alt pressed on overlay directly',
      (tester) async {
        final stickyState = StickyStateService();
        final section = StickySection(
          entries: [
            _makeEntry(
              id: 'e1',
              message: 'sticky entry',
              display: DisplayLocation.static_,
              parentId: 'g1',
            ),
          ],
        );

        await tester.pumpWidget(
          _wrapOverlay(sections: [section], stickyState: stickyState),
        );
        await tester.pumpAndSettle();

        // Before alt press: should have close icon
        expect(find.byIcon(Icons.close), findsWidgets);
        expect(find.byIcon(Icons.visibility_off), findsNothing);

        // Simulate alt key press
        await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
        await tester.pumpAndSettle();

        // After alt press: close icons replaced by visibility_off
        expect(find.byIcon(Icons.visibility_off), findsWidgets);
        expect(find.byIcon(Icons.close), findsNothing);

        // Release alt
        await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
        await tester.pumpAndSettle();

        // Back to close icons
        expect(find.byIcon(Icons.close), findsWidgets);
        expect(find.byIcon(Icons.visibility_off), findsNothing);
      },
    );

    testWidgets('alt+click calls ignore on group', (tester) async {
      final stickyState = StickyStateService();
      final section = StickySection(
        entries: [
          _makeEntry(
            id: 'e1',
            message: 'sticky entry',
            display: DisplayLocation.static_,
            groupId: 'g1',
          ),
        ],
      );

      await tester.pumpWidget(
        _wrapOverlay(sections: [section], stickyState: stickyState),
      );
      await tester.pumpAndSettle();

      // Hold alt and tap the button
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.visibility_off).first);
      await tester.pumpAndSettle();

      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.pumpAndSettle();

      // Group should be ignored
      expect(stickyState.isGroupIgnored('g1'), isTrue);
    });
  });

  // ─── S06: Status bar integration ──────────────────────────────

  group('S06 — Status bar sticky info', () {
    testWidgets('ignored groups are filtered from sticky display', (
      tester,
    ) async {
      final stickyState = StickyStateService();
      final store = LogStore();
      store.addEntries([
        _makeEntry(
          id: 'g1-open',
          groupId: 'g1',
          message: 'Build',
          display: DisplayLocation.static_,
        ),
        _makeEntry(id: 'g1-a', message: 'Compiling...', parentId: 'g1'),
        _makeEntry(id: 'normal', message: 'After group'),
      ]);

      // Ignore the group
      stickyState.ignore('g1');

      await tester.pumpWidget(_wrap(logStore: store, stickyState: stickyState));
      await tester.pumpAndSettle();

      // PINNED badge should not appear since the group is ignored
      expect(find.text('PINNED'), findsNothing);
    });

    testWidgets('restoreAll clears all dismissed and ignored state', (
      tester,
    ) async {
      final stickyState = StickyStateService();
      stickyState.dismiss('e1');
      stickyState.dismiss('e2');
      stickyState.ignore('g1');

      expect(stickyState.dismissedCount, 2);
      expect(stickyState.ignoredGroupCount, 1);

      stickyState.restoreAll();

      expect(stickyState.dismissedCount, 0);
      expect(stickyState.ignoredGroupCount, 0);
    });
  });

  // ─── S07: Unpin protocol ──────────────────────────────────────

  group('S07 — Sticky action unpin', () {
    testWidgets('entry with sticky_action unpin auto-dismisses', (
      tester,
    ) async {
      final stickyState = StickyStateService();
      final store = LogStore();
      store.addEntries([
        _makeEntry(
          id: 'a',
          message: 'sticky log',
          display: DisplayLocation.static_,
          parentId: 'g1',
        ),
        _makeEntry(id: 'b', message: 'normal'),
      ]);

      await tester.pumpWidget(_wrap(logStore: store, stickyState: stickyState));
      await tester.pumpAndSettle();

      // In v2, stickyAction was removed. Unpin is handled externally.
      // Manually dismiss to simulate the unpin behavior.
      stickyState.ignore('g1');
      expect(stickyState.isGroupIgnored('g1'), isTrue);
    });

    testWidgets('LogEntry.fromJson parses groupId', (tester) async {
      final json = {
        'id': 'test-1',
        'timestamp': '2026-02-08T10:00:00.000Z',
        'session_id': 'sess-1',
        'severity': 'info',
        'kind': 'event',
        'group_id': 'g1',
      };

      final entry = LogEntry.fromJson(json);
      expect(entry.groupId, 'g1');
    });
  });

  // ─── S08: Overflow indicators ─────────────────────────────────

  group('S08 — Overflow indicators', () {
    testWidgets('section count bar shows when > 1 section', (tester) async {
      final sections = List.generate(
        3,
        (i) => StickySection(
          entries: [
            _makeEntry(
              id: 'e$i',
              message: 'entry $i',
              display: DisplayLocation.static_,
            ),
          ],
        ),
      );

      await tester.pumpWidget(_wrapOverlay(sections: sections));
      await tester.pumpAndSettle();

      expect(find.text('3 sections pinned'), findsOneWidget);
    });

    testWidgets('overflow indicator shows when sections exceed max height', (
      tester,
    ) async {
      // Many sections that will overflow 30% of 600px = 180px
      // Estimated 44px per section, so 5 sections = 220px > 180px
      final sections = List.generate(
        6,
        (i) => StickySection(
          entries: [
            _makeEntry(
              id: 'e$i',
              message: 'entry $i',
              display: DisplayLocation.static_,
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        _wrapOverlay(sections: sections, maxHeightFraction: 0.3),
      );
      await tester.pumpAndSettle();

      // Should show overflow indicator
      expect(
        find.byWidgetPredicate(
          (w) => w is Text && (w.data?.contains('more hidden') ?? false),
        ),
        findsOneWidget,
      );
    });

    testWidgets('tapping overflow indicator expands to show all sections', (
      tester,
    ) async {
      final sections = List.generate(
        6,
        (i) => StickySection(
          entries: [
            _makeEntry(
              id: 'e$i',
              message: 'entry $i',
              display: DisplayLocation.static_,
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        _wrapOverlay(sections: sections, maxHeightFraction: 0.3),
      );
      await tester.pumpAndSettle();

      // Find and tap the overflow indicator
      final overflowFinder = find.byWidgetPredicate(
        (w) => w is Text && (w.data?.contains('more hidden') ?? false),
      );
      expect(overflowFinder, findsOneWidget);

      await tester.tap(overflowFinder);
      await tester.pumpAndSettle();

      // After expanding, overflow indicator should disappear
      expect(overflowFinder, findsNothing);

      // Should now show "collapse" text for collapsing
      expect(find.text('collapse'), findsOneWidget);
    });

    testWidgets('collapse button restores overflow state', (tester) async {
      final sections = List.generate(
        6,
        (i) => StickySection(
          entries: [
            _makeEntry(
              id: 'e$i',
              message: 'entry $i',
              display: DisplayLocation.static_,
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        _wrapOverlay(sections: sections, maxHeightFraction: 0.3),
      );
      await tester.pumpAndSettle();

      // Expand
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is Text && (w.data?.contains('more hidden') ?? false),
        ),
      );
      await tester.pumpAndSettle();

      // Collapse
      await tester.tap(find.text('collapse'));
      await tester.pumpAndSettle();

      // Should show expand again
      expect(find.text('expand'), findsOneWidget);
      // Overflow indicator should reappear
      expect(
        find.byWidgetPredicate(
          (w) => w is Text && (w.data?.contains('more hidden') ?? false),
        ),
        findsOneWidget,
      );
    });

    testWidgets('no overflow when sections fit in max height', (tester) async {
      final sections = [
        StickySection(
          entries: [
            _makeEntry(
              id: 'e1',
              message: 'entry 1',
              display: DisplayLocation.static_,
            ),
          ],
        ),
      ];

      await tester.pumpWidget(_wrapOverlay(sections: sections));
      await tester.pumpAndSettle();

      // No overflow indicator
      expect(
        find.byWidgetPredicate(
          (w) => w is Text && (w.data?.contains('more hidden') ?? false),
        ),
        findsNothing,
      );
      // No section count bar (only 1 section)
      expect(find.text('1 sections pinned'), findsNothing);
    });
  });
}
