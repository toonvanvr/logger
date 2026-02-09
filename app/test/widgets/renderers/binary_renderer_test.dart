import 'dart:convert';

import 'package:app/models/log_entry.dart';
import 'package:app/theme/theme.dart';
import 'package:app/widgets/renderers/binary_renderer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers.dart';

LogEntry _makeBinaryEntry({String? binary}) {
  return makeTestEntry(
    kind: EntryKind.event,
    widget: binary != null
        ? WidgetPayload(type: 'binary', data: {'data': binary})
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
  group('BinaryRenderer', () {
    // ── Test 1: shows hex dump ──

    testWidgets('shows hex dump for base64 data', (tester) async {
      // base64 for bytes [0x48, 0x65, 0x6c, 0x6c, 0x6f] = "Hello"
      final b64 = base64Encode([0x48, 0x65, 0x6c, 0x6c, 0x6f]);
      await tester.pumpWidget(
        _wrap(BinaryRenderer(entry: _makeBinaryEntry(binary: b64))),
      );

      // Should show hex dump with offset
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Text && w.data != null && w.data!.contains('48 65 6c 6c 6f'),
        ),
        findsOneWidget,
      );
    });

    // ── Test 2: shows byte count ──

    testWidgets('shows byte count', (tester) async {
      final b64 = base64Encode([0x01, 0x02, 0x03]);
      await tester.pumpWidget(
        _wrap(BinaryRenderer(entry: _makeBinaryEntry(binary: b64))),
      );

      expect(find.text('3 bytes'), findsOneWidget);
    });

    // ── Test 3: handles empty binary ──

    testWidgets('handles empty binary', (tester) async {
      await tester.pumpWidget(
        _wrap(BinaryRenderer(entry: _makeBinaryEntry(binary: ''))),
      );

      expect(find.text('0 bytes'), findsOneWidget);
    });
  });
}
