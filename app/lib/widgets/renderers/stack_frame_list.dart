import 'dart:io' show Process;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/log_entry.dart';
import '../../services/settings_service.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';

/// Renders a single stack frame row with clickable file/URL navigation.
class StackFrameWidget extends StatelessWidget {
  final StackFrame frame;

  const StackFrameWidget({super.key, required this.frame});

  @override
  Widget build(BuildContext context) {
    final loc = frame.location;
    final isVendor = frame.isVendor ?? false;

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

    final isUrl =
        loc.uri.startsWith('http://') || loc.uri.startsWith('https://');

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

/// Expand button for showing more stack frames.
class StackFrameExpandButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const StackFrameExpandButton({
    super.key,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
}
