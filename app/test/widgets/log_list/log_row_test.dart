import 'package:app/models/log_entry.dart';
import 'package:app/services/session_store.dart';
import 'package:app/theme/colors.dart';
import 'package:app/theme/theme.dart';
import 'package:app/widgets/log_list/log_row.dart';
import 'package:app/widgets/log_list/log_row_content.dart';
import 'package:app/widgets/log_list/session_dot.dart';
import 'package:app/widgets/log_list/severity_bar.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../test_helpers.dart';

LogEntry _makeEntry({
  String id = 'e1',
  String text = 'hello world',
  Severity severity = Severity.info,
  LogType type = LogType.text,
  String sessionId = 'sess-1',
}) {
  return makeTestEntry(
    id: id,
    text: text,
    severity: severity,
    type: type,
    sessionId: sessionId,
  );
}

Widget _wrap(Widget child) {
  return MultiProvider(
    providers: [ChangeNotifierProvider(create: (_) => SessionStore())],
    child: MaterialApp(
      theme: createLoggerTheme(),
      home: Scaffold(body: child),
    ),
  );
}

Container _findRowContainer(WidgetTester tester) {
  return tester
      .widgetList<Container>(
        find.descendant(
          of: find.byType(LogRow),
          matching: find.byType(Container),
        ),
      )
      .firstWhere(
        (c) =>
            c.decoration is BoxDecoration &&
            (c.decoration as BoxDecoration).border != null,
      );
}

void main() {
  testWidgets('renders text content', (tester) async {
    await tester.pumpWidget(
      _wrap(LogRow(entry: _makeEntry(text: 'test log message'))),
    );

    // TextRenderer uses RichText, so match via predicate.
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is RichText && w.text.toPlainText().contains('test log message'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('shows severity bar with correct width', (tester) async {
    await tester.pumpWidget(
      _wrap(LogRow(entry: _makeEntry(severity: Severity.error))),
    );

    final bar = tester.widget<SizedBox>(
      find.descendant(
        of: find.byType(SeverityBar),
        matching: find.byType(SizedBox),
      ),
    );
    // error = 4px width
    expect(bar.width, 4);
  });

  testWidgets('shows session dot', (tester) async {
    await tester.pumpWidget(
      _wrap(LogRow(entry: _makeEntry(sessionId: 'sess-42'))),
    );

    expect(find.byType(SessionDot), findsOneWidget);
  });

  testWidgets('new entry has highlight animation', (tester) async {
    await tester.pumpWidget(_wrap(LogRow(entry: _makeEntry(), isNew: true)));

    // At t=0 the entry is transparent (opacity animation starting at 0).
    // Use .first to target the row-level animation Opacity (not copy icon).
    final opacity = tester.widget<Opacity>(find.byType(Opacity).first);
    expect(opacity.opacity, 0.0);

    // After pumping 200ms the entry should be fully visible.
    await tester.pump(const Duration(milliseconds: 200));
    final opacityAfter = tester.widget<Opacity>(find.byType(Opacity).first);
    expect(opacityAfter.opacity, closeTo(1.0, 0.05));
  });

  testWidgets('isSelected does not apply bgActive highlight', (tester) async {
    await tester.pumpWidget(
      _wrap(LogRow(entry: _makeEntry(), isSelected: true)),
    );
    await tester.pump();

    final container = _findRowContainer(tester);
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.color, isNot(equals(LoggerColors.bgActive)));
  });

  testWidgets('hover applies dim highlight', (tester) async {
    await tester.pumpWidget(_wrap(LogRow(entry: _makeEntry())));
    await tester.pump();

    final colorBefore =
        (_findRowContainer(tester).decoration as BoxDecoration).color;

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(tester.getCenter(find.byType(LogRow)));
    await tester.pump();

    final colorAfter =
        (_findRowContainer(tester).decoration as BoxDecoration).color;
    expect(colorAfter, isNot(equals(colorBefore)));
  });

  testWidgets('copy button shows checkmark after tap', (tester) async {
    await tester.pumpWidget(_wrap(LogRow(entry: _makeEntry(text: 'copy me'))));
    await tester.pump();

    // Hover to show copy button
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(tester.getCenter(find.byType(LogRow)));
    await tester.pump();

    expect(find.byIcon(Icons.content_copy), findsOneWidget);

    await tester.tap(find.byIcon(Icons.content_copy));
    await tester.pump();

    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(find.byIcon(Icons.content_copy), findsNothing);

    // Reverts after 800ms
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.byIcon(Icons.content_copy), findsOneWidget);
  });

  testWidgets('copy button has pointer cursor on hover', (tester) async {
    await tester.pumpWidget(_wrap(LogRow(entry: _makeEntry())));
    await tester.pump();

    // Hover to show copy button
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(tester.getCenter(find.byType(LogRow)));
    await tester.pump();

    final mouseRegions = tester.widgetList<MouseRegion>(
      find.descendant(
        of: find.byType(LogRowContent),
        matching: find.byType(MouseRegion),
      ),
    );
    final clickCursor = mouseRegions.where(
      (mr) => mr.cursor == SystemMouseCursors.click,
    );
    expect(clickCursor, isNotEmpty);
  });
}
