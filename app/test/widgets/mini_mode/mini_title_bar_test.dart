import 'package:app/theme/theme.dart';
import 'package:app/widgets/mini_mode/mini_title_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _buildTestWidget({
  bool isFilterExpanded = false,
  VoidCallback? onFilterToggle,
  VoidCallback? onSettingsToggle,
}) {
  return MaterialApp(
    theme: createLoggerTheme(),
    home: Scaffold(
      body: MiniTitleBar(
        isFilterExpanded: isFilterExpanded,
        onFilterToggle: onFilterToggle,
        onSettingsToggle: onSettingsToggle,
      ),
    ),
  );
}

void main() {
  testWidgets('does not display Logger text', (tester) async {
    await tester.pumpWidget(_buildTestWidget());

    expect(find.text('Logger'), findsNothing);
  });

  testWidgets('renders filter and settings buttons', (tester) async {
    await tester.pumpWidget(_buildTestWidget());

    expect(find.byIcon(Icons.filter_list), findsOneWidget);
    expect(find.byIcon(Icons.settings), findsOneWidget);
  });
}
