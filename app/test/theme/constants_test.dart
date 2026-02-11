import 'package:app/theme/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Border radii', () {
    test('kBorderRadius is 4', () {
      expect(kBorderRadius, const BorderRadius.all(Radius.circular(4)));
    });

    test('kBorderRadiusSm is 3', () {
      expect(kBorderRadiusSm, const BorderRadius.all(Radius.circular(3)));
    });

    test('kBorderRadiusLg is 6', () {
      expect(kBorderRadiusLg, const BorderRadius.all(Radius.circular(6)));
    });
  });

  group('Colors', () {
    test('kScrimColor is 25% black', () {
      expect(kScrimColor, const Color(0x40000000));
    });

    test('kErrorHintBg is a semi-transparent red', () {
      expect(kErrorHintBg.alpha, lessThan(255));
    });
  });

  group('Font sizes', () {
    test('font sizes are in ascending order', () {
      final sizes = [
        kFontSizeBadge,
        kFontSizeLabel,
        kFontSizeBody,
        kFontSizeSubhead,
        kFontSizeControl,
        kFontSizeIcon,
      ];
      for (var i = 0; i < sizes.length - 1; i++) {
        expect(sizes[i], lessThanOrEqualTo(sizes[i + 1]),
            reason: 'sizes[$i] <= sizes[${i + 1}]');
      }
    });

    test('expected values', () {
      expect(kFontSizeBadge, 8.0);
      expect(kFontSizeLabel, 9.0);
      expect(kFontSizeBody, 10.0);
      expect(kFontSizeSubhead, 11.0);
      expect(kFontSizeControl, 12.0);
      expect(kFontSizeIcon, 14.0);
    });
  });

  group('Padding constants', () {
    test('kHPadding8 is horizontal 8', () {
      expect(kHPadding8, const EdgeInsets.symmetric(horizontal: 8));
    });

    test('kHPadding12 is horizontal 12', () {
      expect(kHPadding12, const EdgeInsets.symmetric(horizontal: 12));
    });

    test('kVPadding4 is vertical 4', () {
      expect(kVPadding4, const EdgeInsets.symmetric(vertical: 4));
    });
  });
}
