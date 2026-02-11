import 'package:flutter/material.dart';

import '../../models/log_entry.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';
import 'cause_chain_renderer.dart';
import 'stack_frame_list.dart';

/// Renders an [ExceptionData] stack trace with collapsible frames.
///
/// By default only the first frame is visible; tapping "N more frames"
/// expands the full list. Vendor frames are dimmed.
/// Stack trace frames are clickable — clicking opens the file in the
/// configured editor. URLs are opened with the system URL handler.
/// Parses a raw stack trace string into [StackFrame] objects.
///
/// Splits on newlines, trims, and skips empty lines.
/// Each line becomes a [StackFrame] with the raw text stored.
List<StackFrame> _parseFrames(String? raw) {
  if (raw == null || raw.isEmpty) return [];
  return raw
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .map(
        (l) => StackFrame(
          location: SourceLocation(uri: l),
          raw: l,
        ),
      )
      .toList();
}

class StackTraceRenderer extends StatefulWidget {
  final ExceptionData exception;

  /// Nesting depth for cause chains (0 = root exception).
  final int causeDepth;

  const StackTraceRenderer({
    super.key,
    required this.exception,
    this.causeDepth = 0,
  });

  @override
  State<StackTraceRenderer> createState() => _StackTraceRendererState();
}

class _StackTraceRendererState extends State<StackTraceRenderer> {
  int _visibleCount = 1;

  @override
  Widget build(BuildContext context) {
    final exception = widget.exception;
    final frames = _parseFrames(exception.stackTrace);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text.rich(
          TextSpan(
            children: [
              if (exception.type != null)
                TextSpan(
                  text: '${exception.type}: ',
                  style: LoggerTypography.logBody.copyWith(
                    color: LoggerColors.syntaxError,
                  ),
                ),
              TextSpan(
                text: exception.message,
                style: LoggerTypography.logBody.copyWith(
                  color: LoggerColors.severityErrorText,
                ),
              ),
            ],
          ),
        ),
        if (frames.isNotEmpty) ...[
          const SizedBox(height: 4),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ...frames
                    .take(_visibleCount)
                    .map(
                      (f) => Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: StackFrameWidget(frame: f),
                      ),
                    ),
                if (_visibleCount < frames.length)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        if (frames.length - _visibleCount > 5)
                          StackFrameExpandButton(
                            label: '5 more',
                            onTap: () => setState(
                              () => _visibleCount = (_visibleCount + 5).clamp(
                                0,
                                frames.length,
                              ),
                            ),
                          ),
                        if (frames.length - _visibleCount > 5)
                          const SizedBox(width: 8),
                        StackFrameExpandButton(
                          label: 'all ${frames.length - _visibleCount}',
                          onTap: () =>
                              setState(() => _visibleCount = frames.length),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (exception.inner != null) ...[
          const SizedBox(height: 6),
          CauseChainWidget(
            firstCause: exception.inner!,
            parentCauseDepth: widget.causeDepth,
          ),
        ],
      ],
    );
  }
}
