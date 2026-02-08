import 'package:flutter/material.dart';

import '../../theme/colors.dart';

/// Maps ANSI standard color indices (0-15) to Ayu Dark theme colors.
///
/// Standard colors (0-7) map to base Ayu Dark tokens.
/// Bright colors (8-15) use brighter variants or literal hex values
/// when no matching token exists.
const Map<int, Color> ansiColorMap = {
  0: LoggerColors.bgOverlay, // Black → #1A1F2B
  1: LoggerColors.severityErrorText, // Red → #F07668
  2: LoggerColors.syntaxString, // Green → #A8CC7E
  3: LoggerColors.syntaxNumber, // Yellow → #E6B455
  4: LoggerColors.syntaxPath, // Blue → #8DA4EF
  5: LoggerColors.syntaxDate, // Magenta → #D99AE6
  6: LoggerColors.syntaxUrl, // Cyan → #6EB5A6
  7: LoggerColors.fgPrimary, // White → #D4CCBA
  8: LoggerColors.severityDebugText, // Bright Black → #636D83
  9: Color(0xFFF4708B), // Bright Red
  10: Color(0xFFB8CC52), // Bright Green
  11: LoggerColors.syntaxNumber, // Bright Yellow → same amber
  12: LoggerColors.severityInfoText, // Bright Blue → #7EB8D0
  13: Color(0xFFE68ABD), // Bright Magenta
  14: Color(0xFF7ACCE6), // Bright Cyan
  15: Color(0xFFFFFFFF), // Bright White
};
