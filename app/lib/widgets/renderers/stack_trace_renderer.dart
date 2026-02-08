import 'dart:io' show Process;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/log_entry.dart';
import '../../services/settings_service.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';

/// Renders an [ExceptionData] stack trace with collapsible frames.
///
/// By default only the first frame is visible; tapping "N more frames"
/// expands the full list. Vendor frames are dimmed.
/// Stack trace frames are clickable — clicking opens the file in the
/// configured editor. URLs are opened with the system URL handler.
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
  bool _causesExpanded = false;

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
                        child: _buildFrame(context, f),
                      ),
                    ),
                if (_visibleCount < frames.length)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        if (frames.length - _visibleCount > 5)
                          _expandButton(
                            '5 more',
                            () => setState(
                              () => _visibleCount = (_visibleCount + 5).clamp(
                                0,
                                frames.length,
                              ),
                            ),
                          ),
                        if (frames.length - _visibleCount > 5)
                          const SizedBox(width: 8),
                        _expandButton(
                          'all ${frames.length - _visibleCount}',
                          () => setState(() => _visibleCount = frames.length),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        // Nested cause chain
        if (exception.cause != null) ...[
          const SizedBox(height: 6),
          _buildCauseChain(context, exception.cause!),
        ],
      ],
    );
  }

  /// Build the cause chain with collapsible deeper causes.
  Widget _buildCauseChain(BuildContext context, ExceptionData firstCause) {
    // Count total causes in the chain.
    int causeCount = 0;
    ExceptionData? current = firstCause;
    while (current != null) {
      causeCount++;
      current = current.cause;
    }

    return Container(
      margin: const EdgeInsets.only(left: 16),
      padding: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: LoggerColors.syntaxError.withAlpha(80),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Caused by:',
            style: LoggerTypography.logMeta.copyWith(
              color: LoggerColors.fgSecondary,
            ),
          ),
          const SizedBox(height: 2),
          // Always show first cause (without its own nested cause rendering).
          StackTraceRenderer(
            exception: ExceptionData(
              type: firstCause.type,
              message: firstCause.message,
              stackTrace: firstCause.stackTrace,
            ),
            causeDepth: widget.causeDepth + 1,
          ),
          // If there are deeper causes beyond the first, show them collapsed.
          if (causeCount > 1 && firstCause.cause != null) ...[
            if (!_causesExpanded)
              GestureDetector(
                onTap: () => setState(() => _causesExpanded = true),
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${causeCount - 1} more cause${causeCount - 1 > 1 ? 's' : ''}',
                    style: LoggerTypography.logMeta.copyWith(
                      color: LoggerColors.syntaxUrl,
                    ),
                  ),
                ),
              ),
            if (_causesExpanded)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: _buildExpandedCauses(firstCause.cause!),
              ),
          ],
        ],
      ),
    );
  }

  /// Recursively build remaining causes when expanded.
  Widget _buildExpandedCauses(ExceptionData cause) {
    return Container(
      margin: const EdgeInsets.only(left: 16),
      padding: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: LoggerColors.syntaxError.withAlpha(80),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Caused by:',
            style: LoggerTypography.logMeta.copyWith(
              color: LoggerColors.fgSecondary,
            ),
          ),
          const SizedBox(height: 2),
          StackTraceRenderer(
            exception: cause,
            causeDepth: widget.causeDepth + 2,
          ),
        ],
      ),
    );
  }

  Widget _expandButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Text(
          '▸ $label',
          style: LoggerTypography.logMeta.copyWith(
            color: LoggerColors.syntaxUrl,
          ),
        ),
      ),
    );
  }

  Widget _buildFrame(BuildContext context, StackFrame frame) {
    final loc = frame.location;
    final isVendor = frame.isVendor ?? false;
    final isUrl =
        loc.uri.startsWith('http://') || loc.uri.startsWith('https://');

    final dimStyle = LoggerTypography.logMeta.copyWith(
      color: LoggerColors.fgMuted,
    );
    final symbolStyle = LoggerTypography.logMeta.copyWith(
      color: isVendor ? LoggerColors.fgMuted : LoggerColors.fgSecondary,
    );
    final pathColor = isVendor ? LoggerColors.fgMuted : LoggerColors.syntaxPath;

    final pathBuf = StringBuffer(loc.uri);
    if (loc.line != null) {
      pathBuf.write(':${loc.line}');
      if (loc.column != null) {
        pathBuf.write(':${loc.column}');
      }
    }

    return SelectionContainer.disabled(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => _onFrameTap(context, loc, isUrl),
          child: Row(
            children: [
              Text('  at ', style: dimStyle),
              if (loc.symbol != null) Text(loc.symbol!, style: symbolStyle),
              if (loc.symbol != null) Text(' ', style: dimStyle),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: LoggerColors.bgSurface,
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Text(
                  pathBuf.toString(),
                  style: LoggerTypography.logMeta.copyWith(color: pathColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onFrameTap(BuildContext context, SourceLocation loc, bool isUrl) {
    final settings = context.read<SettingsService>();

    if (isUrl) {
      final cmd = settings.urlOpenCommand.replaceAll('{url}', loc.uri);
      _runCommand(cmd);
    } else {
      final cmd = settings.fileOpenCommand
          .replaceAll('{file}', loc.uri)
          .replaceAll('{line}', '${loc.line ?? 1}');
      _runCommand(cmd);
    }
  }

  void _runCommand(String cmd) {
    final parts = cmd.split(' ');
    if (parts.isEmpty) return;
    Process.run(parts.first, parts.skip(1).toList());
  }
}
