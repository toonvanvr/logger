import 'package:flutter/material.dart';

/// All color constants from the UX design spec.
class LoggerColors {
  LoggerColors._();

  // ── Backgrounds (§1.1) ──
  static const bgBase = Color(0xFF0B0E14);
  static const bgSurface = Color(0xFF0F1219);
  static const bgRaised = Color(0xFF141820);
  static const bgOverlay = Color(0xFF1A1F2B);
  static const bgHover = Color(0xFF1E2433);
  static const bgActive = Color(0xFF252C3A);
  static const bgDivider = Color(0xFF1C2130);

  // ── Foreground (§1.2) ──
  static const fgPrimary = Color(0xFFD4CCBA);
  static const fgSecondary = Color(0xFF8A8473);
  static const fgMuted = Color(0xFF565165);
  static const fgInverse = Color(0xFF0B0E14);

  // ── Border (§1.3) ──
  static const borderSubtle = Color(0xFF1C2130);
  static const borderDefault = Color(0xFF2A3040);
  static const borderFocus = Color(0xFFE6B455);

  // ── Severity (§1.4) ──
  static const severityDebugBar = Color(0xFF636D83);
  static const severityDebugText = Color(0xFF636D83);
  static const severityInfoBar = Color(0xFF7EB8D0);
  static const severityInfoText = Color(0xFF7EB8D0);
  static const severityWarningBar = Color(0xFFE6B455);
  static const severityWarningText = Color(0xFFE6B455);
  static const severityErrorBar = Color(0xFFE06C60);
  static const severityErrorText = Color(0xFFF07668);
  static const severityCriticalBar = Color(0xFFD94F68);
  static const severityCriticalText = Color(0xFFF4708B);

  // ── Session pool (§1.5) — 12 colors ──
  static const sessionPool = [
    Color(0xFF7EB8D0),
    Color(0xFFE6B455),
    Color(0xFFA8CC7E),
    Color(0xFFD99AE6),
    Color(0xFFF07668),
    Color(0xFF6EB5A6),
    Color(0xFFD4A07A),
    Color(0xFF8DA4EF),
    Color(0xFFE68ABD),
    Color(0xFFB8CC52),
    Color(0xFFCC8C7A),
    Color(0xFF7ACCE6),
  ];

  // ── Syntax highlighting (§1.6) ──
  static const syntaxString = Color(0xFFA8CC7E);
  static const syntaxNumber = Color(0xFFE6B455);
  static const syntaxBoolean = Color(0xFFF07668);
  static const syntaxNull = Color(0xFF636D83);
  static const syntaxKey = Color(0xFF7EB8D0);
  static const syntaxDate = Color(0xFFD99AE6);
  static const syntaxUrl = Color(0xFF6EB5A6);
  static const syntaxProtocol = Color(0xFFD99AE6); // purple for protocol scheme
  static const syntaxPunctuation = Color(0xFF565165);
  static const syntaxError = Color(0xFFF07668);
  static const syntaxPath = Color(0xFF8DA4EF);
  static const syntaxLineNumber = Color(0xFF636D83);
}

/// Maps a severity string to its bar color.
Color severityBarColor(String severity) {
  return switch (severity) {
    'debug' => LoggerColors.severityDebugBar,
    'info' => LoggerColors.severityInfoBar,
    'warning' => LoggerColors.severityWarningBar,
    'error' => LoggerColors.severityErrorBar,
    'critical' => LoggerColors.severityCriticalBar,
    _ => LoggerColors.severityDebugBar,
  };
}

/// Maps a severity string to its text color.
Color severityTextColor(String severity) {
  return switch (severity) {
    'debug' => LoggerColors.severityDebugText,
    'info' => LoggerColors.severityInfoText,
    'warning' => LoggerColors.severityWarningText,
    'error' => LoggerColors.severityErrorText,
    'critical' => LoggerColors.severityCriticalText,
    _ => LoggerColors.severityDebugText,
  };
}
