// Golden-file screenshot test for the Logger app.
//
// Renders the full app UI with mock data in the test harness, then saves
// golden PNG images. No network access required.
//
// Run with:
//   cd /home/toon/work/logger/app && flutter test test/screenshots_test.dart --update-goldens
//
// Golden files are saved to ../../.ai/scratch/2026-02-07_screenshots/

import 'dart:io';

import 'package:app/models/log_entry.dart';
import 'package:app/models/server_message.dart';
import 'package:app/models/viewer_message.dart';
import 'package:app/screens/log_viewer.dart';
import 'package:app/services/log_connection.dart';
import 'package:app/services/log_store.dart';
import 'package:app/services/rpc_service.dart';
import 'package:app/services/session_store.dart';
import 'package:app/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Generate realistic mock log entries covering different types and severities.
List<LogEntry> _buildMockEntries() {
  final now = DateTime.now();
  int seq = 0;
  LogEntry entry({
    Severity severity = Severity.info,
    LogType type = LogType.text,
    String? text,
    String section = 'main',
    dynamic jsonData,
    String? html,
    String? groupId,
    GroupAction? groupAction,
    String? groupLabel,
    String? customType,
    dynamic customData,
    ExceptionData? exception,
    Map<String, String>? tags,
  }) {
    seq++;
    return LogEntry(
      id: 'mock-$seq',
      timestamp: now
          .subtract(Duration(seconds: 300 - seq))
          .toUtc()
          .toIso8601String(),
      sessionId: 'session-demo',
      severity: severity,
      type: type,
      section: section,
      text: text,
      jsonData: jsonData,
      html: html,
      groupId: groupId,
      groupAction: groupAction,
      groupLabel: groupLabel,
      customType: customType,
      customData: customData,
      exception: exception,
      tags: tags,
      application: const ApplicationInfo(
        name: 'demo-app',
        version: '1.0.0',
        environment: 'development',
      ),
    );
  }

  return [
    entry(text: 'Application starting up...', severity: Severity.info),
    entry(text: 'Connecting to database...', severity: Severity.debug),
    entry(
      text: 'Database connected: postgres://localhost:5432/mydb',
      severity: Severity.info,
      tags: {'component': 'db'},
    ),
    entry(
      severity: Severity.info,
      type: LogType.json,
      text: 'Configuration loaded',
      jsonData: {
        'port': 3000,
        'host': '0.0.0.0',
        'debug': true,
        'workers': 4,
        'cache': {'ttl': 3600, 'maxSize': '256MB'},
      },
      section: 'config',
    ),
    entry(
      groupId: 'grp-1',
      groupAction: GroupAction.open,
      groupLabel: 'HTTP Request: GET /api/users',
      severity: Severity.info,
      type: LogType.group,
    ),
    entry(
      text: 'Authenticated user: admin@example.com',
      severity: Severity.debug,
      groupId: 'grp-1',
    ),
    entry(
      text: 'Query executed in 12ms — 47 rows returned',
      severity: Severity.info,
      groupId: 'grp-1',
      tags: {'duration': '12ms'},
    ),
    entry(
      groupId: 'grp-1',
      groupAction: GroupAction.close,
      severity: Severity.info,
      type: LogType.group,
    ),
    entry(
      text: 'Cache miss for key: user-preferences-42',
      severity: Severity.warning,
      section: 'cache',
    ),
    entry(
      text: 'Rate limit approaching: 450/500 requests',
      severity: Severity.warning,
    ),
    entry(
      severity: Severity.error,
      text: 'Failed to process webhook payload',
      exception: const ExceptionData(
        type: 'ValidationError',
        message: 'Invalid JSON body: unexpected token at position 142',
        stackTrace: [
          StackFrame(
            location: SourceLocation(
              uri: 'src/webhooks/handler.ts',
              line: 87,
              column: 12,
              symbol: 'processPayload',
            ),
          ),
          StackFrame(
            location: SourceLocation(
              uri: 'src/middleware/json-parser.ts',
              line: 34,
              symbol: 'parseBody',
            ),
            isVendor: false,
          ),
        ],
      ),
    ),
    entry(
      text: 'Retrying webhook delivery (attempt 2/3)...',
      severity: Severity.warning,
    ),
    entry(
      severity: Severity.critical,
      text: 'CRITICAL: Out of memory — heap usage 98%',
    ),
    entry(
      text: 'Garbage collection completed, freed 120MB',
      severity: Severity.info,
    ),
    entry(
      severity: Severity.info,
      type: LogType.json,
      text: 'Health check response',
      jsonData: {
        'status': 'healthy',
        'uptime': '4h 23m',
        'memory': {'used': '340MB', 'total': '512MB'},
        'connections': {'active': 12, 'idle': 3, 'total': 15},
      },
    ),
    entry(
      text: 'Worker 3 processing background job #1042',
      severity: Severity.debug,
      section: 'workers',
    ),
    entry(
      text: 'Email sent to user@example.com — delivery confirmed',
      severity: Severity.info,
      section: 'notifications',
    ),
    entry(
      text: 'Slow query detected: SELECT * FROM analytics (took 2340ms)',
      severity: Severity.warning,
      section: 'performance',
      tags: {'query_time': '2340ms', 'table': 'analytics'},
    ),
    entry(
      text: 'Deployment v1.2.3 rolled out to 3/3 instances',
      severity: Severity.info,
    ),
  ];
}

Widget _buildTestApp({
  required LogStore logStore,
  required SessionStore sessionStore,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => LogConnection()),
      ChangeNotifierProvider.value(value: logStore),
      ChangeNotifierProvider.value(value: sessionStore),
      ChangeNotifierProvider(create: (_) => RpcService()),
    ],
    child: MaterialApp(
      title: 'Logger',
      debugShowCheckedModeBanner: false,
      theme: createLoggerTheme(),
      home: const LogViewerScreen(serverUrl: null),
    ),
  );
}

void main() {
  // Allow real HTTP requests so google_fonts can fetch fonts
  // and WebSocket connections work.
  setUpAll(() {
    HttpOverrides.global = null;
  });

  testWidgets(
    'golden: app with mock data',
    (WidgetTester tester) async {
      // Desktop-like surface size.
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final logStore = LogStore();
      final sessionStore = SessionStore();

      // Populate stores with mock data.
      sessionStore.updateSessions([
        SessionInfo(
          sessionId: 'session-demo',
          application: const ApplicationInfo(
            name: 'demo-app',
            version: '1.0.0',
            environment: 'development',
          ),
          startedAt: DateTime.now()
              .subtract(const Duration(hours: 1))
              .toUtc()
              .toIso8601String(),
          lastHeartbeat: DateTime.now().toUtc().toIso8601String(),
          isActive: true,
          logCount: 20,
          colorIndex: 0,
        ),
      ]);
      logStore.addEntries(_buildMockEntries());

      await tester.pumpWidget(
        _buildTestApp(logStore: logStore, sessionStore: sessionStore),
      );
      await tester.pump();

      // Capture the full app view.
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          '../../.ai/scratch/2026-02-07_screenshots/golden_app_full.png',
        ),
      );
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
