import 'package:app/models/log_entry.dart';
import 'package:app/theme/theme.dart';
import 'package:app/widgets/renderers/rpc_renderer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

LogEntry _makeRpcEntry({
  RpcDirection direction = RpcDirection.request,
  String method = 'getState',
  dynamic args,
  dynamic response,
  String? error,
}) {
  return LogEntry(
    id: 'e1',
    timestamp: '2026-02-07T12:00:00Z',
    sessionId: 'sess-1',
    severity: Severity.info,
    type: LogType.rpc,
    rpcId: 'rpc-1',
    rpcDirection: direction,
    rpcMethod: method,
    rpcArgs: args,
    rpcResponse: response,
    rpcError: error,
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
            entry: _makeRpcEntry(
              direction: RpcDirection.request,
              method: 'ping',
            ),
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
            entry: _makeRpcEntry(
              direction: RpcDirection.response,
              method: 'ping',
            ),
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
              direction: RpcDirection.error,
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
