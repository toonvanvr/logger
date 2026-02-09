import 'package:flutter/material.dart';

import '../../theme/colors.dart';
import '../../theme/typography.dart';

/// Compact card showing a single state key:value pair.
class StateCard extends StatefulWidget {
  final String stateKey;
  final dynamic stateValue;
  final VoidCallback? onTap;
  final bool isActiveFilter;
  final bool fixedWidth;

  const StateCard({
    super.key,
    required this.stateKey,
    required this.stateValue,
    this.onTap,
    this.isActiveFilter = false,
    this.fixedWidth = false,
  });

  @override
  State<StateCard> createState() => _StateCardState();
}

class _StateCardState extends State<StateCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final displayValue = widget.stateValue?.toString() ?? 'null';
    return MouseRegion(
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Color.lerp(
              widget.isActiveFilter
                  ? Color.lerp(
                      LoggerColors.bgSurface,
                      LoggerColors.severityInfoBar,
                      0.15,
                    )!
                  : LoggerColors.bgSurface,
              Colors.white,
              _isHovered ? 0.05 : 0.0,
            )!,
            borderRadius: BorderRadius.circular(3),
            border: Border(
              left: BorderSide(
                color: widget.isActiveFilter
                    ? LoggerColors.severityInfoBar
                    : LoggerColors.borderSubtle,
                width: widget.isActiveFilter ? 2.0 : 1.0,
              ),
              top: BorderSide(color: LoggerColors.borderSubtle),
              right: BorderSide(color: LoggerColors.borderSubtle),
              bottom: BorderSide(color: LoggerColors.borderSubtle),
            ),
          ),
          child: Row(
            mainAxisSize: widget.fixedWidth
                ? MainAxisSize.max
                : MainAxisSize.min,
            children: [
              Text(
                widget.stateKey,
                style: LoggerTypography.logMeta.copyWith(
                  color: widget.isActiveFilter
                      ? LoggerColors.fgPrimary
                      : LoggerColors.fgMuted,
                  fontSize: 10,
                ),
              ),
              const SizedBox(width: 4),
              if (widget.fixedWidth)
                Expanded(
                  child: Tooltip(
                    message: displayValue,
                    child: Text(
                      displayValue,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: LoggerTypography.logMeta.copyWith(
                        color: LoggerColors.fgPrimary,
                        fontSize: 10,
                      ),
                    ),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 200),
                  child: Tooltip(
                    message: displayValue,
                    child: Text(
                      displayValue,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: LoggerTypography.logMeta.copyWith(
                        color: LoggerColors.fgPrimary,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
              if (widget.isActiveFilter) ...[
                const SizedBox(width: 4),
                Icon(Icons.close, size: 10, color: LoggerColors.fgMuted),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
