import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../theme/colors.dart';
import '../../theme/typography.dart';

/// A compact horizontal time scrubber bar for navigating log history.
class TimeScrubber extends StatefulWidget {
  /// Start of the session (earliest log).
  final DateTime? sessionStart;

  /// End of the session (latest log / now).
  final DateTime? sessionEnd;

  /// Called when the user drags the thumb to a new position.
  /// Provides the visible range (from, to) based on thumb position.
  final Function(DateTime from, DateTime to)? onRangeChanged;

  /// Whether time-travel mode is active.
  final bool isActive;

  /// Toggle time-travel mode on/off.
  final VoidCallback? onToggle;

  const TimeScrubber({
    super.key,
    this.sessionStart,
    this.sessionEnd,
    this.onRangeChanged,
    this.isActive = false,
    this.onToggle,
  });

  @override
  State<TimeScrubber> createState() => TimeScrubberState();
}

@visibleForTesting
class TimeScrubberState extends State<TimeScrubber> {
  double _thumbPosition = 1.0; // 0.0 = start, 1.0 = end (live)

  /// Current thumb position exposed for testing.
  double get thumbPosition => _thumbPosition;

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) return const SizedBox.shrink();

    final start = widget.sessionStart;
    final end = widget.sessionEnd;
    final hasRange = start != null && end != null && end.isAfter(start);

    return Container(
      height: 32,
      color: LoggerColors.bgRaised,
      child: hasRange
          ? GestureDetector(
              onHorizontalDragUpdate: _onDrag,
              child: CustomPaint(
                painter: TimeScrubberPainter(
                  position: _thumbPosition,
                  startTime: start,
                  endTime: end,
                ),
                child: _buildLabels(start, end),
              ),
            )
          : Center(
              child: Text(
                'No time range available',
                style: LoggerTypography.logMeta,
              ),
            ),
    );
  }

  Widget _buildLabels(DateTime start, DateTime end) {
    final fmt = DateFormat('HH:mm:ss');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(fmt.format(start), style: LoggerTypography.timestamp),
          Text(fmt.format(end), style: LoggerTypography.timestamp),
        ],
      ),
    );
  }

  void _onDrag(DragUpdateDetails details) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;

    final width = box.size.width;
    if (width <= 0) return;

    setState(() {
      _thumbPosition = (_thumbPosition + details.delta.dx / width).clamp(
        0.0,
        1.0,
      );
    });

    _emitRange();
  }

  void _emitRange() {
    final start = widget.sessionStart;
    final end = widget.sessionEnd;
    if (start == null || end == null) return;

    final totalMs = end.difference(start).inMilliseconds;
    final posMs = (totalMs * _thumbPosition).round();
    final at = start.add(Duration(milliseconds: posMs));

    // Emit from session start to the thumb position.
    widget.onRangeChanged?.call(start, at);
  }
}

/// Custom painter for the time scrubber track and thumb.
@visibleForTesting
class TimeScrubberPainter extends CustomPainter {
  final double position;
  final DateTime? startTime;
  final DateTime? endTime;

  TimeScrubberPainter({required this.position, this.startTime, this.endTime});

  @override
  void paint(Canvas canvas, Size size) {
    // Track background gradient.
    final trackRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final gradient = LinearGradient(
      colors: [
        LoggerColors.bgActive.withValues(alpha: 0.3),
        LoggerColors.severityInfoBar.withValues(alpha: 0.15),
        LoggerColors.bgActive.withValues(alpha: 0.3),
      ],
    );
    canvas.drawRect(
      trackRect,
      Paint()..shader = gradient.createShader(trackRect),
    );

    // Thumb indicator.
    final thumbX = position.clamp(0.0, 1.0) * size.width;
    final thumbPaint = Paint()
      ..color = LoggerColors.borderFocus
      ..strokeWidth = 2;
    canvas.drawLine(Offset(thumbX, 0), Offset(thumbX, size.height), thumbPaint);

    // Small circle at center of thumb line.
    canvas.drawCircle(
      Offset(thumbX, size.height / 2),
      4,
      Paint()..color = LoggerColors.borderFocus,
    );
  }

  @override
  bool shouldRepaint(covariant TimeScrubberPainter oldDelegate) =>
      oldDelegate.position != position ||
      oldDelegate.startTime != startTime ||
      oldDelegate.endTime != endTime;
}
