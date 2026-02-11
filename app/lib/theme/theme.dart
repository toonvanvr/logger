import 'package:flutter/material.dart';

import 'colors.dart';
import 'constants.dart';

/// Constructs the app-wide [ThemeData] using the Logger color system.
ThemeData createLoggerTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: LoggerColors.bgBase,
    canvasColor: LoggerColors.bgSurface,
    cardColor: LoggerColors.bgRaised,
    dividerColor: LoggerColors.bgDivider,
    colorScheme: const ColorScheme.dark(
      primary: LoggerColors.borderFocus,
      onPrimary: LoggerColors.fgInverse,
      surface: LoggerColors.bgSurface,
      onSurface: LoggerColors.fgPrimary,
      secondary: LoggerColors.severityInfoBar,
      onSecondary: LoggerColors.fgInverse,
      error: LoggerColors.severityErrorBar,
      onError: LoggerColors.fgPrimary,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: LoggerColors.bgRaised,
      foregroundColor: LoggerColors.fgPrimary,
      elevation: 0,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: LoggerColors.bgOverlay,
        borderRadius: kBorderRadius,
        border: Border.all(color: LoggerColors.borderDefault),
      ),
      textStyle: const TextStyle(fontSize: 11, color: LoggerColors.fgPrimary),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: LoggerColors.bgSurface,
      border: OutlineInputBorder(
        borderSide: const BorderSide(color: LoggerColors.borderDefault),
        borderRadius: kBorderRadius,
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: LoggerColors.borderFocus),
        borderRadius: kBorderRadius,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStateProperty.all(LoggerColors.borderDefault),
      radius: const Radius.circular(2),
      thickness: WidgetStateProperty.all(6),
    ),
    iconTheme: const IconThemeData(color: LoggerColors.fgSecondary, size: 16),
  );
}
