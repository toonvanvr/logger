import 'package:app/models/log_entry.dart';
import 'package:app/theme/theme.dart';
import 'package:app/widgets/renderers/rpc_renderer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers.dart';

LogEntry _makeRpcEntry({
  String direction = 'request',
  String method = 'getState',
  dynamic args,
  dynamic response,
  String? error,
}) {
  return makeTestEntry(
    kind: EntryKind.event,
    widget: WidgetPayload(
      type: 'rpc_$direction',
      data: {
        'direction': direction,
        'method': method,
        'args': ?args,
        'response': ?response,
        'error': ?error,
      },
    ),
  );
}

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: createLoggerTheme(),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  group('RpcRenderer', () {
    // ── Test 1: request shows → method ──

    testWidgets('request shows → method', (tester) async {
      await tester.pumpWidget(
        _wrap(
          RpcRenderer(
            entry: _makeRpcEntry(direction: 'request', method: 'ping'),
          ),
        ),
      );

      // Check for the arrow and method in the rendered RichText
      expect(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().contains('→ ping'),
        ),
        findsOneWidget,
      );
    });

    // ── Test 2: response shows ← method ──

    testWidgets('response shows ← method', (tester) async {
      await tester.pumpWidget(
        _wrap(
          RpcRenderer(
            entry: _makeRpcEntry(direction: 'response', method: 'ping'),
          ),
        ),
      );

      expect(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().contains('← ping'),
        ),
        findsOneWidget,
      );
    });

    // ── Test 3: error shows in red (syntaxError color) ──

    testWidgets('error shows error text with syntaxError color', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          RpcRenderer(
            entry: _makeRpcEntry(
              direction: 'error',
              method: 'ping',
              error: 'timeout',
            ),
          ),
        ),
      );

      // Verify the error content is rendered
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is RichText && w.text.toPlainText().contains('✗ ping: timeout'),
        ),
        findsOneWidget,
      );
    });
  });
}
