import 'dart:ui';

import 'package:app/theme/theme.dart';
import 'package:app/widgets/landing/landing_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LogoPainter', () {
    test('shouldRepaint returns false', () {
      final painter = LogoPainter();
      expect(painter.shouldRepaint(LogoPainter()), isFalse);
    });

    test('paint does not throw', () {
      final painter = LogoPainter();
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      expect(
        () => painter.paint(canvas, const Size(64, 64)),
        returnsNormally,
      );
      recorder.endRecording();
    });
  });

  group('StepRow', () {
    testWidgets('renders number, title, and code', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: createLoggerTheme(),
          home: const Scaffold(
            body: StepRow(
              number: '1',
              title: 'Install',
              code: 'bun add logger',
            ),
          ),
        ),
      );

      expect(find.text('1'), findsOneWidget);
      expect(find.text('Install'), findsOneWidget);
      expect(find.text('bun add logger'), findsOneWidget);
    });
  });

  group('KbdChip', () {
    testWidgets('renders key and label', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: createLoggerTheme(),
          home: const Scaffold(
            body: KbdChip(keys: 'Ctrl+K', label: 'Search'),
          ),
        ),
      );

      expect(find.text('Ctrl+K'), findsOneWidget);
      expect(find.text('Search'), findsOneWidget);
    });
  });

  group('LinkPill', () {
    testWidgets('renders icon and label', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: createLoggerTheme(),
          home: const Scaffold(
            body: LinkPill(icon: Icons.book, label: 'Docs'),
          ),
        ),
      );

      expect(find.byIcon(Icons.book), findsOneWidget);
      expect(find.text('Docs'), findsOneWidget);
    });
  });

  group('ConnectButton', () {
    testWidgets('renders connect label and cable icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: createLoggerTheme(),
          home: const Scaffold(body: ConnectButton()),
        ),
      );

      expect(find.byIcon(Icons.cable), findsOneWidget);
      expect(find.text('Connect to Server'), findsOneWidget);
    });

    testWidgets('onTap callback fires', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: createLoggerTheme(),
          home: Scaffold(
            body: ConnectButton(onTap: () => tapped = true),
          ),
        ),
      );

      await tester.tap(find.text('Connect to Server'));
      expect(tapped, isTrue);
    });
  });
}
