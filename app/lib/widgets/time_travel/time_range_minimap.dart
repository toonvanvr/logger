import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../services/time_range_service.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';
import 'minimap_painter.dart';

export 'minimap_painter.dart' show MinimapPainter;

part 'time_range_minimap_gestures.dart';

/// A minimap bar showing log density over time with a draggable viewport.
///
/// 48dp tall. Shows stacked severity bars, a viewport rectangle with
/// drag handles, and time labels. Supports drag, scroll-zoom, click-jump,
/// and double-click-reset interactions.
class TimeRangeMinimap extends StatefulWidget {
  const TimeRangeMinimap({super.key});

  @override
  State<TimeRangeMinimap> createState() => _TimeRangeMinimapState();
}

class _TimeRangeMinimapState extends State<TimeRangeMinimap>
    with _MinimapGestures {
  @override
  Widget build(BuildContext context) {
    final service = context.read<TimeRangeService>();
    final (buckets, maxCount, vpStart, vpEnd, isActive, sessStart, sessEnd) =
        context.select<
            TimeRangeService,
            (List<BucketData>, int, double, double, bool, DateTime?,
                DateTime?)>(
      (s) => (
        s.buckets,
        s.maxBucketCount,
        s.viewportStartNorm,
        s.viewportEndNorm,
        s.isActive,
        s.sessionStart,
        s.sessionEnd,
      ),
    );

    if (buckets.isEmpty) return const SizedBox.shrink();

    return Container(
      height: _height,
      decoration: const BoxDecoration(
        color: LoggerColors.bgSurface,
        border: Border(
          top: BorderSide(color: LoggerColors.borderSubtle, width: 1),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return GestureDetector(
            onDoubleTap: () => service.resetRange(),
            child: Listener(
              onPointerSignal: (event) => _onPointerSignal(event, width),
              child: MouseRegion(
                onHover: (event) => _updateHover(event, service, width),
                onExit: (_) => _clearHover(),
                cursor: _currentCursor(),
                child: GestureDetector(
                  onPanStart: (d) => _onPanStart(d, service, width),
                  onPanUpdate: (d) => _onPanUpdate(d, service, width),
                  onPanEnd: (_) => _onPanEnd(),
                  onTapUp: (d) => _onTapUp(d, service, width),
                  child: CustomPaint(
                    painter: MinimapPainter(
                      buckets: buckets,
                      maxCount: maxCount,
                      vpStart: vpStart,
                      vpEnd: vpEnd,
                      isActive: isActive,
                      leftHandleHovered: _leftHandleHovered,
                      rightHandleHovered: _rightHandleHovered,
                    ),
                    child: _buildLabels(service),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLabels(TimeRangeService service) {
    final start = service.sessionStart;
    final end = service.sessionEnd;
    if (start == null || end == null) return const SizedBox.expand();

    final fmt = DateFormat('HH:mm:ss');
    return Padding(
      padding: const EdgeInsets.fromLTRB(_hPadding, 0, _hPadding, 0),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 1),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                fmt.format(start.toLocal()),
                style: LoggerTypography.timestamp,
              ),
              Text(
                fmt.format(end.toLocal()),
                style: LoggerTypography.timestamp,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
