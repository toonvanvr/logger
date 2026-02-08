import 'package:flutter/material.dart';

import 'ansi_theme.dart';

/// A segment of text with associated ANSI styling.
class AnsiSegment {
  final String text;
  final Color? foreground;
  final Color? background;
  final bool bold;
  final bool dim;
  final bool italic;
  final bool underline;

  const AnsiSegment({
    required this.text,
    this.foreground,
    this.background,
    this.bold = false,
    this.dim = false,
    this.italic = false,
    this.underline = false,
  });
}

/// Returns `true` if [text] contains any ANSI escape sequences.
bool hasAnsiCodes(String text) => text.contains('\x1B[');

final _ansiPattern = RegExp(r'\x1B\[([0-9;]*)m');

/// Parses [text] containing ANSI SGR escape codes into styled segments.
List<AnsiSegment> parseAnsi(String text) {
  final segments = <AnsiSegment>[];
  Color? fg, bg;
  var bold = false, dim = false, italic = false, underline = false;
  var lastEnd = 0;

  void emit(String t) {
    if (t.isEmpty) return;
    segments.add(
      AnsiSegment(
        text: t,
        foreground: fg,
        background: bg,
        bold: bold,
        dim: dim,
        italic: italic,
        underline: underline,
      ),
    );
  }

  for (final match in _ansiPattern.allMatches(text)) {
    if (match.start > lastEnd) emit(text.substring(lastEnd, match.start));
    lastEnd = match.end;

    final params = match.group(1) ?? '';
    final codes = params.isEmpty
        ? [0]
        : params.split(';').map((s) => int.tryParse(s) ?? 0).toList();

    var i = 0;
    while (i < codes.length) {
      final code = codes[i];
      switch (code) {
        case 0:
          fg = bg = null;
          bold = dim = italic = underline = false;
        case 1:
          bold = true;
        case 2:
          dim = true;
        case 3:
          italic = true;
        case 4:
          underline = true;
        case 22:
          bold = dim = false;
        case 23:
          italic = false;
        case 24:
          underline = false;
        case >= 30 && <= 37:
          fg = ansiColorMap[code - 30];
        case 38:
          if (i + 1 < codes.length &&
              codes[i + 1] == 5 &&
              i + 2 < codes.length) {
            fg = _color256(codes[i + 2]);
            i += 2;
          } else if (i + 1 < codes.length &&
              codes[i + 1] == 2 &&
              i + 4 < codes.length) {
            fg = Color.fromARGB(255, codes[i + 2], codes[i + 3], codes[i + 4]);
            i += 4;
          }
        case 39:
          fg = null;
        case >= 40 && <= 47:
          bg = ansiColorMap[code - 40];
        case 48:
          if (i + 1 < codes.length &&
              codes[i + 1] == 5 &&
              i + 2 < codes.length) {
            bg = _color256(codes[i + 2]);
            i += 2;
          } else if (i + 1 < codes.length &&
              codes[i + 1] == 2 &&
              i + 4 < codes.length) {
            bg = Color.fromARGB(255, codes[i + 2], codes[i + 3], codes[i + 4]);
            i += 4;
          }
        case 49:
          bg = null;
        case >= 90 && <= 97:
          fg = ansiColorMap[code - 90 + 8];
        case >= 100 && <= 107:
          bg = ansiColorMap[code - 100 + 8];
      }
      i++;
    }
  }

  if (lastEnd < text.length) emit(text.substring(lastEnd));
  return segments;
}

/// Converts a 256-color index to a [Color].
Color _color256(int n) {
  if (n < 16) return ansiColorMap[n]!;
  if (n < 232) {
    n -= 16;
    final r = (n ~/ 36) * 51;
    final g = ((n % 36) ~/ 6) * 51;
    final b = (n % 6) * 51;
    return Color.fromARGB(255, r, g, b);
  }
  final gray = 8 + (n - 232) * 10;
  return Color.fromARGB(255, gray, gray, gray);
}
