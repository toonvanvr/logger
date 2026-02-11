import 'package:flutter/material.dart';

import '../../theme/colors.dart';
import '../../theme/constants.dart';
import '../../theme/typography.dart';

/// Geometric "L" logo painter — amber stroke wh quadratic curve.
class LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = LoggerColors.borderFocus
      ..strokeWidth = size.width * 0.125
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final sx = size.width / 64;
    final sy = size.height / 64;
    final path = Path()
      ..moveTo(16 * sx, 14 * sy)
      ..lineTo(16 * sx, 42 * sy)
      ..quadraticBezierTo(16 * sx, 50 * sy, 24 * sx, 50 * sy)
      ..lineTo(48 * sx, 50 * sy);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Quick-start step row.
class StepRow extends StatelessWidget {
  final String number, title, code;
  const StepRow({
    super.key,
    required this.number,
    required this.title,
    required this.code,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: LoggerColors.bgSurface,
              borderRadius: kBorderRadius,
            ),
            alignment: Alignment.center,
            child: Text(number, style: LoggerTypography.stepNumber),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _titleStyle),
                const SizedBox(height: 2),
                Text(code, style: _codeStyle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class KbdChip extends StatelessWidget {
  final String keys, label;
  const KbdChip({super.key, required this.keys, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: LoggerColors.bgSurface,
        borderRadius: kBorderRadiusSm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(keys, style: _kbdKeyStyle),
          const SizedBox(width: 4),
          Text(label, style: _kbdLabelStyle),
        ],
      ),
    );
  }
}

class LinkPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const LinkPill({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: LoggerColors.bgSurface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: LoggerColors.fgMuted),
              const SizedBox(width: 6),
              Text(label, style: _linkStyle),
            ],
          ),
        ),
      ),
    );
  }
}

class ConnectButton extends StatelessWidget {
  final VoidCallback? onTap;
  const ConnectButton({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: LoggerColors.bgRaised,
            border: Border.all(color: LoggerColors.borderFocus),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cable,
                size: 16,
                color: LoggerColors.borderFocus,
              ),
              const SizedBox(width: 8),
              Text('Connect to Server', style: _connectStyle),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shared text styles ──

final _titleStyle = LoggerTypography.bodySmall;
final _codeStyle = LoggerTypography.codeSnippet;
final _kbdKeyStyle = LoggerTypography.kbdKey;
final _kbdLabelStyle = LoggerTypography.kbdLabel;
final _linkStyle = LoggerTypography.linkLabel;
final _connectStyle = LoggerTypography.connectBtn;
