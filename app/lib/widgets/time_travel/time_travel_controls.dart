import 'package:flutter/material.dart';

import '../../theme/colors.dart';
import '../../theme/typography.dart';
import 'time_scrubber.dart';

/// Minimal controls for time-travel mode.
///
/// Layout: [⏪ toggle] [time_scrubber] [🔴 LIVE]
class TimeTravelControls extends StatelessWidget {
  /// Whether time-travel mode is currently active.
  final bool isActive;

  /// Toggle time-travel mode on/off.
  final VoidCallback onToggle;

  /// Jump back to live (latest) logs.
  final VoidCallback onGoToLive;

  /// Session start time for the scrubber.
  final DateTime? sessionStart;

  /// Session end time for the scrubber.
  final DateTime? sessionEnd;

  /// Called when the scrubber thumb moves.
  final Function(DateTime from, DateTime to)? onRangeChanged;

  const TimeTravelControls({
    super.key,
    required this.isActive,
    required this.onToggle,
    required this.onGoToLive,
    this.sessionStart,
    this.sessionEnd,
    this.onRangeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      decoration: const BoxDecoration(
        color: LoggerColors.bgRaised,
        border: Border(
          top: BorderSide(color: LoggerColors.borderSubtle, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Toggle button
          _IconBtn(
            icon: Icons.history,
            tooltip: isActive ? 'Exit time travel' : 'Enter time travel',
            isActive: isActive,
            onPressed: onToggle,
          ),

          // Scrubber (expands to fill)
          Expanded(
            child: TimeScrubber(
              isActive: isActive,
              sessionStart: sessionStart,
              sessionEnd: sessionEnd,
              onRangeChanged: onRangeChanged,
            ),
          ),

          // LIVE button
          if (isActive) _LiveButton(onPressed: onGoToLive),
        ],
      ),
    );
  }
}

// ─── Private helpers ─────────────────────────────────────────────────

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool isActive;
  final VoidCallback onPressed;

  const _IconBtn({
    required this.icon,
    required this.tooltip,
    required this.isActive,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Icon(
            icon,
            size: 16,
            color: isActive
                ? LoggerColors.borderFocus
                : LoggerColors.fgSecondary,
          ),
        ),
      ),
    );
  }
}

class _LiveButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _LiveButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Go to live',
      child: InkWell(
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: LoggerColors.severityErrorBar,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text('LIVE', style: LoggerTypography.badge),
            ],
          ),
        ),
      ),
    );
  }
}
