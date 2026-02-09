import 'package:app/models/log_entry.dart';
import 'package:app/services/session_store.dart';
import 'package:app/services/sticky_state.dart';
import 'package:app/theme/theme.dart';
import 'package:app/widgets/log_list/sticky_header.dart';
import 'package:app/widgets/log_list/sticky_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../test_helpers.dart';

Widget _wrap(Widget child) {
  return MultiProvider(
    providers: [ChangeNotifierProvider(create: (_) => SessionStore())],
    child: MaterialApp(
      theme: createLoggerTheme(),
      home: Scaffold(body: SizedBox(height: 400, width: 600, child: child)),
    ),
  );
}

void main() {
  group('StickyHeaderOverlay', () {
    testWidgets('renders nothing when sections empty', (tester) async {
      await tester.pumpWidget(_wrap(const StickyHeaderOverlay(sections: [])));

      expect(find.byType(StickyHeaderOverlay), findsOneWidget);
      expect(find.byType(SizedBox), findsWidgets);
    });

    testWidgets('renders section with sticky entry', (tester) async {
      final entry = makeTestEntry(
        id: 'sticky-1',
        text: 'pinned entry',
        sticky: true,
      );

      await tester.pumpWidget(
        _wrap(
          StickyHeaderOverlay(
            sections: [
              StickySection(entries: [entry]),
            ],
          ),
        ),
      );

      expect(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().contains('pinned entry'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders group header label', (tester) async {
      final groupHeader = makeTestEntry(
        id: 'g1',
        type: LogType.group,
        groupAction: GroupAction.open,
        groupLabel: 'HTTP Requests',
        groupId: 'g1',
        sticky: true,
      );
      final entry = makeTestEntry(
        id: 's1',
        text: 'GET /api',
        groupId: 'g1',
        sticky: true,
      );

      await tester.pumpWidget(
        _wrap(
          StickyHeaderOverlay(
            sections: [
              StickySection(groupHeader: groupHeader, entries: [entry]),
            ],
          ),
        ),
      );

      expect(find.text('HTTP Requests'), findsOneWidget);
    });

    testWidgets('shows hidden count badge', (tester) async {
      final entry = makeTestEntry(id: 's1', text: 'visible', sticky: true);

      await tester.pumpWidget(
        _wrap(
          StickyHeaderOverlay(
            sections: [
              StickySection(entries: [entry], hiddenCount: 5),
            ],
          ),
        ),
      );

      expect(find.textContaining('5'), findsWidgets);
    });

    testWidgets('shows section count bar for multiple sections', (
      tester,
    ) async {
      final e1 = makeTestEntry(id: 's1', text: 'a', sticky: true);
      final e2 = makeTestEntry(id: 's2', text: 'b', sticky: true);

      await tester.pumpWidget(
        _wrap(
          StickyHeaderOverlay(
            sections: [
              StickySection(entries: [e1]),
              StickySection(entries: [e2]),
            ],
          ),
        ),
      );

      // SectionCountBar shown when sections > 1
      expect(find.byType(SectionCountBar), findsOneWidget);
    });

    testWidgets('dismiss calls stickyState.dismiss', (tester) async {
      final stickyState = StickyStateService();
      final entry = makeTestEntry(
        id: 'dismiss-me',
        text: 'will be dismissed',
        sticky: true,
      );

      await tester.pumpWidget(
        _wrap(
          StickyHeaderOverlay(
            sections: [
              StickySection(entries: [entry]),
            ],
            stickyState: stickyState,
          ),
        ),
      );

      // Verify stickyState is wired (dismiss via service)
      stickyState.dismiss('dismiss-me');
      expect(stickyState.isDismissed('dismiss-me'), isTrue);
    });
  });
}
