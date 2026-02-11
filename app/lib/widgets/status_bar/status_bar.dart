import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/log_store.dart';
import '../../services/sticky_state.dart';
import '../../theme/colors.dart';
import '../../theme/constants.dart';
import 'status_bar_segments.dart';

/// A subtle status bar at the bottom of the app showing entry count,
/// memory estimate, and connection status.
class StatusBar extends StatelessWidget {
  const StatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    final entryCount = context.select<LogStore, int>((s) => s.entryCount);
    final memoryBytes = context.select<LogStore, int>(
      (s) => s.estimatedMemoryBytes,
    );
    final dismissed = context.select<StickyStateService, int>(
      (s) => s.dismissedCount,
    );
    final ignored = context.select<StickyStateService, int>(
      (s) => s.ignoredGroupCount,
    );
    final hasStickyInfo = dismissed > 0 || ignored > 0;

    return Container(
      height: 20,
      color: LoggerColors.bgBase,
      padding: kHPadding8,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 400;
          return Row(
            children: [
              StatusItem(
                icon: Icons.storage_outlined,
                label: '$entryCount entries',
                isWarning: entryCount > 8000,
              ),
              if (!narrow) ...[
                const SizedBox(width: 12),
                StatusItem(
                  icon: Icons.memory_outlined,
                  label: _formatMemory(memoryBytes),
                  isWarning: memoryBytes > 100 * 1024 * 1024,
                ),
              ],
              if (hasStickyInfo && !narrow) ...[
                const SizedBox(width: 12),
                StickyStatusSection(
                  dismissed: dismissed,
                  ignored: ignored,
                  onRestoreAll: context.read<StickyStateService>().restoreAll,
                ),
              ],
              const Spacer(),
              const ConnectionIndicator(),
            ],
          );
        },
      ),
    );
  }

  static String _formatMemory(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
