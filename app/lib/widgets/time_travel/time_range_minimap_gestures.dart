part of 'time_range_minimap.dart';

/// Layout and hit-testing constants for the minimap.
const double _height = 48.0;
const double _hPadding = 8.0;
const double _handleHitWidth = 12.0;

/// Drag interaction mode for viewport manipulation.
enum _DragMode { none, viewport, leftHandle, rightHandle }

/// Gesture handling for [TimeRangeMinimap].
///
/// Manages drag, hover, tap, and scroll-zoom interactions on the
/// minimap viewport. Mixed into [_TimeRangeMinimapState].
mixin _MinimapGestures on State<TimeRangeMinimap> {
  _DragMode _dragMode = _DragMode.none;
  bool _leftHandleHovered = false;
  bool _rightHandleHovered = false;
  bool _viewportHovered = false;

  // ── Hit testing helpers ──

  double _barAreaWidth(double totalWidth) => totalWidth - 2 * _hPadding;

  double _vpLeftX(TimeRangeService s, double totalWidth) =>
      _hPadding + s.viewportStartNorm * _barAreaWidth(totalWidth);

  double _vpRightX(TimeRangeService s, double totalWidth) =>
      _hPadding + s.viewportEndNorm * _barAreaWidth(totalWidth);

  bool _isOnLeftHandle(double x, TimeRangeService s, double w) {
    final handleX = _vpLeftX(s, w);
    return (x - handleX).abs() < _handleHitWidth / 2;
  }

  bool _isOnRightHandle(double x, TimeRangeService s, double w) {
    final handleX = _vpRightX(s, w);
    return (x - handleX).abs() < _handleHitWidth / 2;
  }

  bool _isInsideViewport(double x, TimeRangeService s, double w) {
    final left = _vpLeftX(s, w);
    final right = _vpRightX(s, w);
    return x > left + _handleHitWidth / 2 && x < right - _handleHitWidth / 2;
  }

  // ── Hover ──

  void _updateHover(PointerHoverEvent event, TimeRangeService s, double w) {
    if (!s.isActive) {
      _clearHover();
      return;
    }
    final x = event.localPosition.dx;
    setState(() {
      _leftHandleHovered = _isOnLeftHandle(x, s, w);
      _rightHandleHovered = _isOnRightHandle(x, s, w);
      _viewportHovered =
          !_leftHandleHovered &&
          !_rightHandleHovered &&
          _isInsideViewport(x, s, w);
    });
  }

  void _clearHover() {
    if (_leftHandleHovered || _rightHandleHovered || _viewportHovered) {
      setState(() {
        _leftHandleHovered = false;
        _rightHandleHovered = false;
        _viewportHovered = false;
      });
    }
  }

  MouseCursor _currentCursor() {
    if (_dragMode == _DragMode.viewport) return SystemMouseCursors.grabbing;
    if (_dragMode == _DragMode.leftHandle ||
        _dragMode == _DragMode.rightHandle) {
      return SystemMouseCursors.resizeColumn;
    }
    if (_leftHandleHovered || _rightHandleHovered) {
      return SystemMouseCursors.resizeColumn;
    }
    if (_viewportHovered) return SystemMouseCursors.grab;
    return SystemMouseCursors.click;
  }

  // ── Drag ──

  void _onPanStart(DragStartDetails d, TimeRangeService s, double w) {
    final x = d.localPosition.dx;
    if (s.isActive && _isOnLeftHandle(x, s, w)) {
      _dragMode = _DragMode.leftHandle;
    } else if (s.isActive && _isOnRightHandle(x, s, w)) {
      _dragMode = _DragMode.rightHandle;
    } else if (s.isActive && _isInsideViewport(x, s, w)) {
      _dragMode = _DragMode.viewport;
    } else {
      _dragMode = _DragMode.none;
    }
    setState(() {});
  }

  void _onPanUpdate(DragUpdateDetails d, TimeRangeService s, double w) {
    if (s.sessionStart == null || s.sessionEnd == null) return;
    final sessionDur = s.sessionEnd!.difference(s.sessionStart!);
    final barWidth = _barAreaWidth(w);
    if (barWidth <= 0) return;

    final deltaNorm = d.delta.dx / barWidth;
    final deltaUs = (sessionDur.inMicroseconds * deltaNorm).round();

    switch (_dragMode) {
      case _DragMode.viewport:
        s.panBy(Duration(microseconds: deltaUs));
      case _DragMode.leftHandle:
        final newStart = s.rangeStart!.add(Duration(microseconds: deltaUs));
        s.setRange(newStart, s.rangeEnd!);
      case _DragMode.rightHandle:
        final newEnd = s.rangeEnd!.add(Duration(microseconds: deltaUs));
        s.setRange(s.rangeStart!, newEnd);
      case _DragMode.none:
        // Start a new drag from outside viewport — set range centered
        // on current position.
        break;
    }
  }

  void _onPanEnd() {
    setState(() => _dragMode = _DragMode.none);
  }

  // ── Tap ──

  void _onTapUp(TapUpDetails d, TimeRangeService s, double w) {
    if (s.sessionStart == null || s.sessionEnd == null) return;
    final barWidth = _barAreaWidth(w);
    if (barWidth <= 0) return;

    final norm = ((d.localPosition.dx - _hPadding) / barWidth).clamp(0.0, 1.0);
    final sessionDur = s.sessionEnd!.difference(s.sessionStart!);

    if (!s.isActive) {
      // First tap: zoom to 50% centered on click.
      final halfDur = Duration(
        microseconds: (sessionDur.inMicroseconds * 0.25).round(),
      );
      final center = s.sessionStart!.add(
        Duration(microseconds: (sessionDur.inMicroseconds * norm).round()),
      );
      s.setRange(center.subtract(halfDur), center.add(halfDur));
    } else {
      // Center viewport on click position.
      final rangeDur = s.rangeEnd!.difference(s.rangeStart!);
      final halfRange = Duration(microseconds: rangeDur.inMicroseconds ~/ 2);
      final center = s.sessionStart!.add(
        Duration(microseconds: (sessionDur.inMicroseconds * norm).round()),
      );
      s.setRange(center.subtract(halfRange), center.add(halfRange));
    }
  }

  // ── Scroll zoom ──

  void _onPointerSignal(PointerSignalEvent event, double w) {
    if (event is! PointerScrollEvent) return;
    final s = context.read<TimeRangeService>();
    if (s.sessionStart == null || s.sessionEnd == null) return;

    final shiftHeld =
        HardwareKeyboard.instance.logicalKeysPressed.contains(
          LogicalKeyboardKey.shiftLeft,
        ) ||
        HardwareKeyboard.instance.logicalKeysPressed.contains(
          LogicalKeyboardKey.shiftRight,
        );

    if (shiftHeld) {
      // Shift+scroll: pan.
      if (!s.isActive) return;
      final rangeDur = s.rangeEnd!.difference(s.rangeStart!);
      final panAmount = Duration(
        microseconds: (rangeDur.inMicroseconds * 0.1).round(),
      );
      if (event.scrollDelta.dy > 0) {
        s.panBy(panAmount);
      } else {
        s.panBy(-panAmount);
      }
    } else {
      // Scroll: zoom centered on cursor X.
      final barWidth = _barAreaWidth(w);
      final norm = barWidth > 0
          ? ((event.localPosition.dx - _hPadding) / barWidth).clamp(0.0, 1.0)
          : 0.5;
      final factor = event.scrollDelta.dy > 0 ? 1.15 : 0.85;
      s.zoomBy(factor, anchor: norm);
    }
  }
}
