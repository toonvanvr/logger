import 'package:app/theme/typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  // GoogleFonts styles trigger async font loading that fails in test.
  // Use testWidgets so the test framework handles font loading errors.
  testWidgets('LoggerTypography styles have correct fontSize values',
      (tester) async {
    final checks = <String, double>{
      'logBody': LoggerTypography.logBody.fontSize!,
      'logMeta': LoggerTypography.logMeta.fontSize!,
      'groupTitle': LoggerTypography.groupTitle.fontSize!,
      'sectionH': LoggerTypography.sectionH.fontSize!,
      'headerBtn': LoggerTypography.headerBtn.fontSize!,
      'badge': LoggerTypography.badge.fontSize!,
      'tooltip': LoggerTypography.tooltip.fontSize!,
      'drawer': LoggerTypography.drawer.fontSize!,
      'timestamp': LoggerTypography.timestamp.fontSize!,
      'landingTitle': LoggerTypography.landingTitle.fontSize!,
      'landingSubtitle': LoggerTypography.landingSubtitle.fontSize!,
      'smallLabel': LoggerTypography.smallLabel.fontSize!,
      'stepNumber': LoggerTypography.stepNumber.fontSize!,
      'linkLabel': LoggerTypography.linkLabel.fontSize!,
      'bodySmall': LoggerTypography.bodySmall.fontSize!,
      'connectBtn': LoggerTypography.connectBtn.fontSize!,
      'codeSnippet': LoggerTypography.codeSnippet.fontSize!,
      'kbdKey': LoggerTypography.kbdKey.fontSize!,
      'kbdLabel': LoggerTypography.kbdLabel.fontSize!,
    };

    expect(checks['logBody'], 12);
    expect(checks['logMeta'], 10);
    expect(checks['groupTitle'], 12);
    expect(checks['sectionH'], 11);
    expect(checks['headerBtn'], 11);
    expect(checks['badge'], 9);
    expect(checks['tooltip'], 11);
    expect(checks['drawer'], 12);
    expect(checks['timestamp'], 10);
    expect(checks['landingTitle'], 20);
    expect(checks['landingSubtitle'], 12);
    expect(checks['smallLabel'], 10);
    expect(checks['stepNumber'], 10);
    expect(checks['linkLabel'], 11);
    expect(checks['bodySmall'], 11);
    expect(checks['connectBtn'], 12);
    expect(checks['codeSnippet'], 10);
    expect(checks['kbdKey'], 10);
    expect(checks['kbdLabel'], 10);
  });

  testWidgets('LoggerTypography styles have correct fontWeight',
      (tester) async {
    expect(LoggerTypography.groupTitle.fontWeight, FontWeight.w600);
    expect(LoggerTypography.sectionH.fontWeight, FontWeight.w700);
    expect(LoggerTypography.headerBtn.fontWeight, FontWeight.w500);
    expect(LoggerTypography.badge.fontWeight, FontWeight.w700);
    expect(LoggerTypography.tooltip.fontWeight, FontWeight.w400);
    expect(LoggerTypography.stepNumber.fontWeight, FontWeight.w600);
    expect(LoggerTypography.bodySmall.fontWeight, FontWeight.w500);
    expect(LoggerTypography.connectBtn.fontWeight, FontWeight.w600);
  });

  testWidgets('all styles have fontSize between 8 and 24', (tester) async {
    final styles = [
      LoggerTypography.logBody,
      LoggerTypography.logMeta,
      LoggerTypography.groupTitle,
      LoggerTypography.sectionH,
      LoggerTypography.headerBtn,
      LoggerTypography.badge,
      LoggerTypography.tooltip,
      LoggerTypography.drawer,
      LoggerTypography.timestamp,
      LoggerTypography.landingTitle,
      LoggerTypography.landingSubtitle,
      LoggerTypography.smallLabel,
      LoggerTypography.stepNumber,
      LoggerTypography.linkLabel,
      LoggerTypography.bodySmall,
      LoggerTypography.connectBtn,
      LoggerTypography.codeSnippet,
      LoggerTypography.kbdKey,
      LoggerTypography.kbdLabel,
    ];
    for (final s in styles) {
      expect(s.fontSize, greaterThanOrEqualTo(8));
      expect(s.fontSize, lessThanOrEqualTo(24));
    }
  });
}
