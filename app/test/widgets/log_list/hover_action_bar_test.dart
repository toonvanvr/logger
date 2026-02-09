import 'package:app/models/log_entry.dart';
import 'package:app/theme/colors.dart';
import 'package:app/theme/theme.dart';
import 'package:app/widgets/log_list/hover_action_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers.dart';

LogEntry _entry() => makeTestEntry(id: 'e1', message: 'hello');

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: createLoggerTheme(),
    home: Scaffold(body: child),
  );
}

void main() {
  group('HoverActionBar', () {
    testWidgets('renders action icons', (tester) async {
      await tester.pumpWidget(
        _wrap(
          HoverActionBar(
            entry: _entry(),
            backgroundColor: LoggerColors.bgSurface,
            actions: [
              RowAction(
                id: 'copy',
                icon: Icons.content_copy,
                tooltip: 'Copy',
                onTap: (_) {},
              ),
              RowAction(
                id: 'pin',
                icon: Icons.push_pin_outlined,
                tooltip: 'Pin',
                onTap: (_) {},
              ),
            ],
          ),
        ),
      );

      expect(find.byIcon(Icons.content_copy), findsOneWidget);
      expect(find.byIcon(Icons.push_pin_outlined), findsOneWidget);
    });

    testWidgets('tap calls action callback', (tester) async {
      String? tappedId;

      await tester.pumpWidget(
        _wrap(
          HoverActionBar(
            entry: _entry(),
            backgroundColor: LoggerColors.bgSurface,
            actions: [
              RowAction(
                id: 'copy',
                icon: Icons.content_copy,
                tooltip: 'Copy',
                onTap: (entry) => tappedId = entry.id,
              ),
            ],
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.content_copy));
      expect(tappedId, 'e1');
    });

    testWidgets('active state shows accent color', (tester) async {
      await tester.pumpWidget(
        _wrap(
          HoverActionBar(
            entry: _entry(),
            backgroundColor: LoggerColors.bgSurface,
            actions: [
              RowAction(
                id: 'pinned',
                icon: Icons.push_pin,
                tooltip: 'Pinned',
                onTap: (_) {},
                isActive: (_) => true,
              ),
            ],
          ),
        ),
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.push_pin));
      expect(icon.color, LoggerColors.syntaxString);
    });

    testWidgets('inactive state shows muted color', (tester) async {
      await tester.pumpWidget(
        _wrap(
          HoverActionBar(
            entry: _entry(),
            backgroundColor: LoggerColors.bgSurface,
            actions: [
              RowAction(
                id: 'copy',
                icon: Icons.content_copy,
                tooltip: 'Copy',
                onTap: (_) {},
              ),
            ],
          ),
        ),
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.content_copy));
      expect(icon.color, LoggerColors.fgMuted);
    });

    testWidgets('overflow popup appears when actions exceed maxVisible', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          HoverActionBar(
            entry: _entry(),
            backgroundColor: LoggerColors.bgSurface,
            maxVisible: 2,
            actions: [
              RowAction(
                id: 'a1',
                icon: Icons.content_copy,
                tooltip: 'Action 1',
                onTap: (_) {},
              ),
              RowAction(
                id: 'a2',
                icon: Icons.push_pin,
                tooltip: 'Action 2',
                onTap: (_) {},
              ),
              RowAction(
                id: 'a3',
                icon: Icons.filter_alt,
                tooltip: 'Action 3',
                onTap: (_) {},
              ),
            ],
          ),
        ),
      );

      // First action visible, overflow icon present
      expect(find.byIcon(Icons.content_copy), findsOneWidget);
      expect(find.byIcon(Icons.more_horiz), findsOneWidget);
      // Overflowed actions not directly visible
      expect(find.byIcon(Icons.push_pin), findsNothing);
      expect(find.byIcon(Icons.filter_alt), findsNothing);

      // Tap overflow to open popup
      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pumpAndSettle();

      // Popup shows overflowed action labels
      expect(find.text('Action 2'), findsOneWidget);
      expect(find.text('Action 3'), findsOneWidget);
    });

    testWidgets('overflow popup calls callback on selection', (tester) async {
      String? tappedId;

      await tester.pumpWidget(
        _wrap(
          HoverActionBar(
            entry: _entry(),
            backgroundColor: LoggerColors.bgSurface,
            maxVisible: 1,
            actions: [
              RowAction(
                id: 'a1',
                icon: Icons.content_copy,
                tooltip: 'Action 1',
                onTap: (_) {},
              ),
              RowAction(
                id: 'a2',
                icon: Icons.push_pin,
                tooltip: 'Action 2',
                onTap: (entry) => tappedId = entry.id,
              ),
            ],
          ),
        ),
      );

      // Tap overflow
      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pumpAndSettle();

      // Select overflowed action
      await tester.tap(find.text('Action 2'));
      await tester.pumpAndSettle();

      expect(tappedId, 'e1');
    });

    testWidgets('empty actions renders SizedBox.shrink', (tester) async {
      await tester.pumpWidget(
        _wrap(
          HoverActionBar(
            entry: _entry(),
            backgroundColor: LoggerColors.bgSurface,
            actions: const [],
          ),
        ),
      );

      expect(find.byType(SizedBox), findsOneWidget);
    });
  });
}
