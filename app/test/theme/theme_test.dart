import 'package:app/theme/colors.dart';
import 'package:app/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LoggerColors', () {
    // ── Test 1: session pool has 12 entries ──

    test('session pool has 12 entries', () {
      expect(LoggerColors.sessionPool, hasLength(12));
    });
  });

  group('severityBarColor', () {
    // ── Test 2: returns correct colors ──

    test('returns correct colors for each severity', () {
      expect(severityBarColor('debug'), LoggerColors.severityDebugBar);
      expect(severityBarColor('info'), LoggerColors.severityInfoBar);
      expect(severityBarColor('warning'), LoggerColors.severityWarningBar);
      expect(severityBarColor('error'), LoggerColors.severityErrorBar);
      expect(severityBarColor('critical'), LoggerColors.severityCriticalBar);
      expect(severityBarColor('unknown'), LoggerColors.severityDebugBar);
    });
  });

  group('createLoggerTheme', () {
    // ── Test 3: returns dark theme with correct scaffold color ──

    test('returns dark theme with correct scaffold color', () {
      final theme = createLoggerTheme();

      expect(theme.brightness, Brightness.dark);
      expect(theme.scaffoldBackgroundColor, LoggerColors.bgBase);
      expect(theme.colorScheme.primary, LoggerColors.borderFocus);
    });
  });
}
