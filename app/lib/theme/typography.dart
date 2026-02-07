import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'colors.dart';

/// Typography constants from UX design spec §2.2.
class LoggerTypography {
  LoggerTypography._();

  /// Log line content — mono 12dp w400
  static TextStyle logBody = GoogleFonts.jetBrainsMono(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.35,
    color: LoggerColors.fgPrimary,
  );

  /// Timestamps, line numbers — mono 10dp w400
  static TextStyle logMeta = GoogleFonts.jetBrainsMono(
    fontSize: 10,
    fontWeight: FontWeight.w400,
    height: 1.20,
    color: LoggerColors.fgSecondary,
  );

  /// Group header text — mono 12dp w600
  static TextStyle groupTitle = GoogleFonts.jetBrainsMono(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.35,
    color: LoggerColors.fgPrimary,
  );

  /// Section names — ui 11dp w700
  static TextStyle sectionH = GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    height: 1.30,
    letterSpacing: 0.8,
    color: LoggerColors.fgPrimary,
  );

  /// Header app session buttons — ui 11dp w500
  static TextStyle headerBtn = GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.30,
    color: LoggerColors.fgPrimary,
  );

  /// Count badges, severity labels — ui 9dp w700
  static TextStyle badge = GoogleFonts.inter(
    fontSize: 9,
    fontWeight: FontWeight.w700,
    height: 1.30,
    letterSpacing: 0.5,
    color: LoggerColors.fgPrimary,
  );

  /// Tooltip text — ui 11dp w400
  static TextStyle tooltip = GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    height: 1.30,
    color: LoggerColors.fgPrimary,
  );

  /// Drawer panel text — ui 12dp w400
  static TextStyle drawer = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.30,
    color: LoggerColors.fgPrimary,
  );

  /// Timestamps in time-travel mode — mono 10dp w400
  static TextStyle timestamp = GoogleFonts.jetBrainsMono(
    fontSize: 10,
    fontWeight: FontWeight.w400,
    height: 1.20,
    color: LoggerColors.fgSecondary,
  );
}
