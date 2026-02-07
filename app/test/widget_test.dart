import 'package:app/screens/log_viewer.dart';
import 'package:app/services/log_connection.dart';
import 'package:app/services/log_store.dart';
import 'package:app/services/session_store.dart';
import 'package:app/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('LogViewerScreen renders header and placeholder', (
    WidgetTester tester,
  ) async {
    // Build the screen with providers but without triggering post-frame WS connect.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LogConnection()),
          ChangeNotifierProvider(create: (_) => LogStore()),
          ChangeNotifierProvider(create: (_) => SessionStore()),
        ],
        child: MaterialApp(
          theme: createLoggerTheme(),
          home: const LogViewerScreen(serverUrl: null),
        ),
      ),
    );

    // Verify the static UI renders before the post-frame callback fires.
    expect(find.text('Logger'), findsOneWidget);
    expect(find.text('Waiting for logs...'), findsOneWidget);
  });
}
