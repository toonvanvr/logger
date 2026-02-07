import 'package:flutter/material.dart';

import '../../models/log_entry.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';

/// Renders an [ExceptionData] stack trace with collapsible frames.
///
/// By default only the first frame is visible; tapping "N more frames"
/// expands the full list. Vendor frames are dimmed.
class StackTraceRenderer extends StatefulWidget {
  final ExceptionData exception;

  const StackTraceRenderer({super.key, required this.exception});

  @override
  State<StackTraceRenderer> createState() => _StackTraceRendererState();
}

class _StackTraceRendererState extends State<StackTraceRenderer> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final exception = widget.exception;
    final frames = exception.stackTrace ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Exception type + message
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
          _buildFrame(frames.first),
          if (frames.length > 1 && !_expanded)
            GestureDetector(
              onTap: () => setState(() => _expanded = true),
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '${frames.length - 1} more frames',
                  style: LoggerTypography.logMeta.copyWith(
                    color: LoggerColors.syntaxUrl,
                  ),
                ),
              ),
            ),
          if (_expanded)
            ...frames
                .skip(1)
                .map(
                  (f) => Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: _buildFrame(f),
                  ),
                ),
        ],
        // Nested cause
        if (exception.cause != null) ...[
          const SizedBox(height: 6),
          Text(
            'Caused by:',
            style: LoggerTypography.logMeta.copyWith(
              color: LoggerColors.fgSecondary,
            ),
          ),
          const SizedBox(height: 2),
          StackTraceRenderer(exception: exception.cause!),
        ],
      ],
    );
  }

  Widget _buildFrame(StackFrame frame) {
    final loc = frame.location;
    final isVendor = frame.isVendor ?? false;
    final color = isVendor ? LoggerColors.fgMuted : LoggerColors.syntaxPath;

    final parts = StringBuffer(loc.uri);
    if (loc.line != null) {
      parts.write(':${loc.line}');
      if (loc.column != null) {
        parts.write(':${loc.column}');
      }
    }
    if (loc.symbol != null) {
      parts.write(' in ${loc.symbol}');
    }

    return Text(
      parts.toString(),
      style: LoggerTypography.logMeta.copyWith(color: color),
    );
  }
}
