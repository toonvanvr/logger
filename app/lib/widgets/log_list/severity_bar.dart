import 'package:flutter/material.dart';

import '../../models/log_entry.dart';
import '../../theme/colors.dart';

/// Left-edge color bar indicating log severity.
///
/// Width varies by severity: debug=1, info=2, warning=3, error=4, critical=5.
/// Color is the saturated severity bar color from the spec.
class SeverityBar extends StatelessWidget {
  final Severity severity;

  const SeverityBar({super.key, required this.severity});

  /// Bar width in logical pixels per severity level.
  double get width => switch (severity) {
    Severity.debug => 1,
    Severity.info => 2,
    Severity.warning => 3,
    Severity.error => 4,
    Severity.critical => 5,
  };

  /// Bar color per severity level.
  Color get color => switch (severity) {
    Severity.debug => LoggerColors.severityDebugBar,
    Severity.info => LoggerColors.severityInfoBar,
    Severity.warning => LoggerColors.severityWarningBar,
    Severity.error => LoggerColors.severityErrorBar,
    Severity.critical => LoggerColors.severityCriticalBar,
  };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: ColoredBox(color: color),
    );
  }
}
