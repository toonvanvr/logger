import 'package:app/models/log_entry.dart';
import 'package:app/theme/theme.dart';
import 'package:app/widgets/renderers/image_renderer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers.dart';

LogEntry _makeImageEntry({Map<String, dynamic>? imageData}) {
  return makeTestEntry(
    kind: EntryKind.event,
    widget: imageData != null
        ? WidgetPayload(type: 'image', data: imageData)
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
  group('ImageRenderer', () {
    // ── Test 1: shows ref placeholder when only ref provided ──

    testWidgets('shows ref placeholder when only ref provided', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ImageRenderer(
            entry: _makeImageEntry(
              imageData: const {'ref': 'https://example.com/image.png'},
            ),
          ),
        ),
      );

      expect(find.text('https://example.com/image.png'), findsOneWidget);
    });

    // ── Test 2: shows label when provided ──

    testWidgets('shows label when provided', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ImageRenderer(
            entry: _makeImageEntry(
              imageData: const {
                'ref': 'https://example.com/image.png',
                'label': 'Screenshot',
                'width': 800,
                'height': 600,
              },
            ),
          ),
        ),
      );

      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Text &&
              w.data != null &&
              w.data!.contains('Screenshot') &&
              w.data!.contains('800×600'),
        ),
        findsOneWidget,
      );
    });
  });
}
