import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/server_message.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';

const _headerHeight = 40.0;
const _sessionDotSize = 6.0;
const _buttonHPadding = 8.0;
const _buttonMaxWidth = 120.0;
const _buttonMinWidth = 48.0;

/// A single session button in the header.
class SessionButton extends StatefulWidget {
  final SessionInfo session;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onCtrlTap;
  final VoidCallback? onShiftTap;

  const SessionButton({
    super.key,
    required this.session,
    required this.isSelected,
    required this.onTap,
    required this.onCtrlTap,
    this.onShiftTap,
  });

  @override
  State<SessionButton> createState() => _SessionButtonState();
}

class _SessionButtonState extends State<SessionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final poolColor =
        LoggerColors.sessionPool[widget.session.colorIndex %
            LoggerColors.sessionPool.length];

    Color bg;
    if (widget.isSelected) {
      bg = LoggerColors.bgActive;
    } else if (_hovered) {
      bg = LoggerColors.bgHover;
    } else {
      bg = Colors.transparent;
    }

    final textColor = widget.isSelected
        ? LoggerColors.fgPrimary
        : LoggerColors.fgSecondary;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () {
          final isShift =
              HardwareKeyboard.instance.logicalKeysPressed.contains(
                LogicalKeyboardKey.shiftLeft,
              ) ||
              HardwareKeyboard.instance.logicalKeysPressed.contains(
                LogicalKeyboardKey.shiftRight,
              );
          final isCtrl =
              HardwareKeyboard.instance.logicalKeysPressed.contains(
                LogicalKeyboardKey.controlLeft,
              ) ||
              HardwareKeyboard.instance.logicalKeysPressed.contains(
                LogicalKeyboardKey.controlRight,
              );

          if (isShift) {
            widget.onShiftTap?.call();
          } else if (isCtrl) {
            widget.onCtrlTap();
          } else {
            widget.onTap();
          }
        },
        child: Container(
          constraints: const BoxConstraints(
            minWidth: _buttonMinWidth,
            maxWidth: _buttonMaxWidth,
          ),
          height: _headerHeight,
          decoration: BoxDecoration(
            color: bg,
            border: Border(
              right: const BorderSide(
                color: LoggerColors.borderSubtle,
                width: 1,
              ),
              bottom: widget.isSelected
                  ? BorderSide(color: poolColor, width: 2)
                  : BorderSide.none,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: _buttonHPadding),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: _sessionDotSize,
                height: _sessionDotSize,
                decoration: BoxDecoration(
                  color: poolColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  widget.session.application.name,
                  style: LoggerTypography.headerBtn.copyWith(color: textColor),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
