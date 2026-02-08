import '../../models/log_entry.dart';

/// A display-ready entry with computed group depth and state.
class DisplayEntry {
  final LogEntry entry;
  final int depth;
  final bool isSticky;
  final String? parentGroupId;

  /// True when this group-open has no visible children (text filtering).
  final bool isStandalone;
  final bool isAutoClose;

  const DisplayEntry({
    required this.entry,
    required this.depth,
    this.isSticky = false,
    this.parentGroupId,
    this.isStandalone = false,
    this.isAutoClose = false,
  });
}

/// Process entries to compute group depths and filter collapsed groups.
List<DisplayEntry> processGrouping({
  required List<LogEntry> entries,
  required String? textFilter,
  required Set<String> collapsedGroups,
  Set<String>? stickyOverrideIds,
}) {
  // Pre-scan to find group IDs that have at least one non-group child.
  final groupIdsWithChildren = <String>{};
  {
    final stack = <String>[];
    for (final entry in entries) {
      if (entry.type == LogType.group) {
        if (entry.groupAction == GroupAction.open) {
          stack.add(entry.groupId ?? entry.id);
        } else if (entry.groupAction == GroupAction.close) {
          if (stack.isNotEmpty) stack.removeLast();
        }
      } else if (stack.isNotEmpty) {
        groupIdsWithChildren.add(stack.last);
      }
    }
  }

  final hasTextFilter = textFilter != null && textFilter.isNotEmpty;
  final result = <DisplayEntry>[];
  int depth = 0;
  final groupStack = <String>[];
  final stickyGroupIds = <String>{};

  for (final entry in entries) {
    bool isHidden = false;
    for (final gid in groupStack) {
      if (collapsedGroups.contains(gid)) {
        isHidden = true;
        break;
      }
    }

    final parentGroupId = groupStack.isNotEmpty ? groupStack.last : null;

    if (entry.type == LogType.group) {
      if (entry.groupAction == GroupAction.open) {
        final gid = entry.groupId ?? entry.id;
        final isSticky = entry.sticky == true;
        if (isSticky) stickyGroupIds.add(gid);
        final hasChildren = groupIdsWithChildren.contains(gid);

        if (!isHidden) {
          if (!hasChildren && hasTextFilter) {
            result.add(
              DisplayEntry(
                entry: entry,
                depth: depth,
                isSticky: isSticky,
                parentGroupId: parentGroupId,
                isStandalone: true,
              ),
            );
          } else {
            result.add(
              DisplayEntry(
                entry: entry,
                depth: depth,
                isSticky: isSticky,
                parentGroupId: parentGroupId,
              ),
            );
          }
        }
        groupStack.add(gid);
        depth++;
      } else if (entry.groupAction == GroupAction.close) {
        if (depth > 0) depth--;
        final closedId = groupStack.isNotEmpty ? groupStack.removeLast() : null;
        if (closedId != null) stickyGroupIds.remove(closedId);

        final closeHasChildren =
            closedId != null && groupIdsWithChildren.contains(closedId);
        if (!isHidden && (closeHasChildren || !hasTextFilter)) {
          result.add(
            DisplayEntry(
              entry: entry,
              depth: depth,
              parentGroupId: parentGroupId,
            ),
          );
        }
      }
    } else {
      if (!isHidden) {
        final isInStickyGroup = groupStack.any(
          (gid) => stickyGroupIds.contains(gid),
        );
        final isSticky =
            entry.sticky == true ||
            isInStickyGroup ||
            (stickyOverrideIds?.contains(entry.id) ?? false);
        result.add(
          DisplayEntry(
            entry: entry,
            depth: depth,
            isSticky: isSticky,
            parentGroupId: parentGroupId,
          ),
        );
      }
    }
  }

  // Auto-close remaining open groups to prevent depth corruption.
  while (groupStack.isNotEmpty) {
    if (depth > 0) depth--;
    final gid = groupStack.removeLast();
    stickyGroupIds.remove(gid);
    result.add(
      DisplayEntry(
        entry: LogEntry(
          id: '${gid}_autoclose',
          timestamp: entries.last.timestamp,
          sessionId: entries.last.sessionId,
          severity: entries.last.severity,
          type: LogType.group,
          groupAction: GroupAction.close,
          groupId: gid,
        ),
        depth: depth,
        isAutoClose: true,
        parentGroupId: groupStack.isNotEmpty ? groupStack.last : null,
      ),
    );
  }

  return result;
}
