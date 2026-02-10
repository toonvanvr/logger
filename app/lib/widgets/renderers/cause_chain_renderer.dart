import 'package:flutter/material.dart';

import '../../models/log_entry.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';
import 'stack_trace_renderer.dart';

/// Renders a collapsible cause chain for nested exceptions.
///
/// Always shows the first cause; deeper causes are collapsed behind a
/// "N more causes" toggle.
class CauseChainWidget extends StatefulWidget {
  final ExceptionData firstCause;
  final int parentCauseDepth;

  const CauseChainWidget({
    super.key,
    required this.firstCause,
    required this.parentCauseDepth,
  });

  @override
  State<CauseChainWidget> createState() => _CauseChainWidgetState();
}

class _CauseChainWidgetState extends State<CauseChainWidget> {
  bool _causesExpanded = false;

  @override
  Widget build(BuildContext context) {
    final firstCause = widget.firstCause;

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
            causeDepth: widget.parentCauseDepth + 1,
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
            causeDepth: widget.parentCauseDepth + 2,
          ),
        ],
      ),
    );
  }
}
