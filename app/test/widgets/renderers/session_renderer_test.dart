import 'package:app/models/log_entry.dart';
import 'package:app/theme/theme.dart';
import 'package:app/widgets/renderers/session_renderer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_helpers.dart';

LogEntry _makeSessionEntry({
  SessionAction action = SessionAction.start,
  String appName = 'MyApp',
  String? version,
}) {
  return makeTestEntry(
    type: LogType.session,
    sessionAction: action,
    application: ApplicationInfo(name: appName, version: version),
  );
}

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: createLoggerTheme(),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  group('SessionRenderer', () {
    // ── Test 1: start shows app name + version ──

    testWidgets('start shows app name and version', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SessionRenderer(
            entry: _makeSessionEntry(
              action: SessionAction.start,
              appName: 'TestApp',
              version: '1.2.3',
            ),
          ),
        ),
      );

      expect(find.text('Session started: TestApp v1.2.3'), findsOneWidget);
    });

    // ── Test 2: end shows "ended" text ──

    testWidgets('end shows ended text', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SessionRenderer(
            entry: _makeSessionEntry(
              action: SessionAction.end,
              appName: 'TestApp',
            ),
          ),
        ),
      );

      expect(find.text('Session ended: TestApp'), findsOneWidget);
    });

    // ── Test 3: heartbeat shows muted text ──

    testWidgets('heartbeat shows muted text', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SessionRenderer(
            entry: _makeSessionEntry(action: SessionAction.heartbeat),
          ),
        ),
      );

      expect(find.text('heartbeat'), findsOneWidget);
    });
  });
}
