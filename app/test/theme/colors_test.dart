import 'package:app/theme/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LoggerColors constants', () {
    test('background colors are non-null opaque', () {
      for (final c in [
        LoggerColors.bgBase,
        LoggerColors.bgSurface,
        LoggerColors.bgRaised,
        LoggerColors.bgOverlay,
        LoggerColors.bgHover,
        LoggerColors.bgActive,
        LoggerColors.bgDivider,
      ]) {
        expect(c.alpha, 255, reason: '$c should be opaque');
      }
    });

    test('foreground colors are non-null', () {
      expect(LoggerColors.fgPrimary, isNotNull);
      expect(LoggerColors.fgSecondary, isNotNull);
      expect(LoggerColors.fgMuted, isNotNull);
      expect(LoggerColors.fgInverse, isNotNull);
    });

    test('border colors are non-null', () {
      expect(LoggerColors.borderSubtle, isNotNull);
      expect(LoggerColors.borderDefault, isNotNull);
      expect(LoggerColors.borderFocus, isNotNull);
    });

    test('severity colors come in bar/text pairs', () {
      for (final sev in ['Debug', 'Info', 'Warning', 'Error', 'Critical']) {
        // Verify both bar and text colors exist (via the helper functions)
        expect(severityBarColor(sev.toLowerCase()), isA<Color>());
        expect(severityTextColor(sev.toLowerCase()), isA<Color>());
      }
    });
  });

  group('LoggerColors.sessionPool', () {
    // session pool length is tested in theme_test.dart; test uniqueness here
    test('all colors are unique', () {
      final unique = LoggerColors.sessionPool.toSet();
      expect(unique.length, LoggerColors.sessionPool.length);
    });

    test('all colors are opaque', () {
      for (final c in LoggerColors.sessionPool) {
        expect(c.alpha, 255, reason: '$c should be opaque');
      }
    });
  });

  group('LoggerColors syntax', () {
    test('syntax colors are non-null', () {
      expect(LoggerColors.syntaxString, isNotNull);
      expect(LoggerColors.syntaxNumber, isNotNull);
      expect(LoggerColors.syntaxBoolean, isNotNull);
      expect(LoggerColors.syntaxNull, isNotNull);
      expect(LoggerColors.syntaxKey, isNotNull);
      expect(LoggerColors.syntaxDate, isNotNull);
      expect(LoggerColors.syntaxUrl, isNotNull);
      expect(LoggerColors.syntaxPunctuation, isNotNull);
      expect(LoggerColors.syntaxError, isNotNull);
      expect(LoggerColors.syntaxPath, isNotNull);
      expect(LoggerColors.syntaxLineNumber, isNotNull);
    });
  });

  group('severityTextColor', () {
    test('returns correct colors for each severity', () {
      expect(severityTextColor('debug'), LoggerColors.severityDebugText);
      expect(severityTextColor('info'), LoggerColors.severityInfoText);
      expect(severityTextColor('warning'), LoggerColors.severityWarningText);
      expect(severityTextColor('error'), LoggerColors.severityErrorText);
      expect(severityTextColor('critical'), LoggerColors.severityCriticalText);
    });

    test('defaults to debug for unknown', () {
      expect(severityTextColor('bogus'), LoggerColors.severityDebugText);
    });
  });

  group('LoggerColors overlays', () {
    test('scrim has alpha channel', () {
      expect(LoggerColors.scrim.alpha, lessThan(255));
    });

    test('highlight has alpha channel', () {
      expect(LoggerColors.highlight.alpha, lessThan(255));
    });
  });
}
