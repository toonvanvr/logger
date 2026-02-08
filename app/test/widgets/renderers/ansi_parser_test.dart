import 'package:app/widgets/renderers/ansi_parser.dart';
import 'package:app/widgets/renderers/ansi_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('hasAnsiCodes', () {
    test('returns true for text with ANSI codes', () {
      expect(hasAnsiCodes('\x1B[31mhello\x1B[0m'), isTrue);
    });

    test('returns false for plain text', () {
      expect(hasAnsiCodes('hello world'), isFalse);
    });
  });

  group('parseAnsi', () {
    test('plain text returns single unstyled segment', () {
      final segments = parseAnsi('hello world');
      expect(segments, hasLength(1));
      expect(segments[0].text, 'hello world');
      expect(segments[0].foreground, isNull);
      expect(segments[0].background, isNull);
      expect(segments[0].bold, isFalse);
    });

    test('red text maps to correct foreground', () {
      final segments = parseAnsi('\x1B[31mhello\x1B[0m');
      expect(segments, hasLength(1));
      expect(segments[0].text, 'hello');
      expect(segments[0].foreground, ansiColorMap[1]);
    });

    test('bold and italic flags set correctly', () {
      final segments = parseAnsi('\x1B[1;3mtext\x1B[0m');
      expect(segments, hasLength(1));
      expect(segments[0].bold, isTrue);
      expect(segments[0].italic, isTrue);
    });

    test('256-color foreground computes correct color', () {
      // Index 196: 196-16=180, r=180~/36=5→255, g=(180%36)~/6=0→0, b=0%6→0
      final segments = parseAnsi('\x1B[38;5;196mred\x1B[0m');
      expect(segments[0].foreground, const Color.fromARGB(255, 255, 0, 0));
    });

    test('RGB foreground sets exact color', () {
      final segments = parseAnsi('\x1B[38;2;100;150;200mrgb\x1B[0m');
      expect(segments[0].foreground, const Color.fromARGB(255, 100, 150, 200));
    });

    test('reset clears all styles', () {
      final segments = parseAnsi('\x1B[1;31mbold red\x1B[0m plain');
      expect(segments, hasLength(2));
      expect(segments[0].bold, isTrue);
      expect(segments[0].foreground, ansiColorMap[1]);
      expect(segments[1].text, ' plain');
      expect(segments[1].bold, isFalse);
      expect(segments[1].foreground, isNull);
    });

    test('malformed sequence preserves text', () {
      // Empty params treated as reset (code 0).
      final segments = parseAnsi('before\x1B[mafter');
      expect(segments.map((s) => s.text).join(), 'beforeafter');
    });

    test('unclosed style applies to remainder', () {
      final segments = parseAnsi('\x1B[1mbold to end');
      expect(segments, hasLength(1));
      expect(segments[0].text, 'bold to end');
      expect(segments[0].bold, isTrue);
    });

    test('empty segments are skipped', () {
      // Two consecutive escapes with no text between.
      final segments = parseAnsi('\x1B[31m\x1B[1mtext\x1B[0m');
      expect(segments, hasLength(1));
      expect(segments[0].text, 'text');
      expect(segments[0].foreground, ansiColorMap[1]);
      expect(segments[0].bold, isTrue);
    });

    test('nested styles: green overrides red, bold persists', () {
      final segments = parseAnsi('\x1B[1;31mred\x1B[32mgreen\x1B[0m');
      expect(segments, hasLength(2));
      expect(segments[0].foreground, ansiColorMap[1]);
      expect(segments[0].bold, isTrue);
      expect(segments[1].foreground, ansiColorMap[2]);
      expect(segments[1].bold, isTrue);
    });

    test('bright foreground colors map correctly', () {
      final segments = parseAnsi('\x1B[90mgray\x1B[0m');
      expect(segments[0].foreground, ansiColorMap[8]);
    });

    test('background color sets correctly', () {
      final segments = parseAnsi('\x1B[41mred bg\x1B[0m');
      expect(segments[0].background, ansiColorMap[1]);
    });
  });
}
