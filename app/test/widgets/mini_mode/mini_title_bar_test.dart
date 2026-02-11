import 'package:app/theme/theme.dart';
import 'package:app/widgets/mini_mode/mini_title_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _buildTestWidget({VoidCallback? onSettingsToggle}) {
  return MaterialApp(
    theme: createLoggerTheme(),
    home: Scaffold(body: MiniTitleBar(onSettingsToggle: onSettingsToggle)),
  );
}

void main() {
  testWidgets('does not display Logger text', (tester) async {
    await tester.pumpWidget(_buildTestWidget());

    expect(find.text('Logger'), findsNothing);
  });

  testWidgets('renders settings button', (tester) async {
    await tester.pumpWidget(_buildTestWidget());

    expect(find.byIcon(Icons.settings), findsOneWidget);
  });
}
