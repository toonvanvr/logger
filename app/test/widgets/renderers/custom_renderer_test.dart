import 'package:app/models/log_entry.dart';
import 'package:app/theme/theme.dart';
import 'package:app/widgets/renderers/custom_renderer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers.dart';

LogEntry _makeCustomEntry({
  String? customType,
  Map<String, dynamic>? customData,
}) {
  return makeTestEntry(
    kind: EntryKind.event,
    widget: customType != null
        ? WidgetPayload(type: customType, data: customData ?? {})
        : null,
  );
}

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: createLoggerTheme(),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  group('CustomRenderer', () {
    // ── Test 1: shows custom type label ──

    testWidgets('shows custom type label', (tester) async {
      await tester.pumpWidget(
        _wrap(CustomRenderer(entry: _makeCustomEntry(customType: 'metric'))),
      );

      expect(find.text('[metric]'), findsOneWidget);
    });

    // ── Test 2: formats data as JSON ──

    testWidgets('formats data as JSON', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CustomRenderer(
            entry: _makeCustomEntry(
              customType: 'event',
              customData: {'cpu': 87.5},
            ),
          ),
        ),
      );

      expect(find.text('[event]'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is Text && w.data != null && w.data!.contains('"cpu": 87.5'),
        ),
        findsOneWidget,
      );
    });
  });
}
