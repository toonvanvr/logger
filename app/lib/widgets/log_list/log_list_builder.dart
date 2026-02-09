import '../../models/log_entry.dart';
import '../../services/log_store.dart';

/// A display-ready entry with computed group depth and state.
class DisplayEntry {
  final LogEntry entry;
  final int depth;
  final int stackDepth;
  final bool isSticky;
  final String? parentGroupId;

  /// True when this group-open has no visible children (text filtering).
  final bool isStandalone;
  final bool isAutoClose;

  const DisplayEntry({
    required this.entry,
    required this.depth,
    this.stackDepth = 1,
    this.isSticky = false,
    this.parentGroupId,
    this.isStandalone = false,
    this.isAutoClose = false,
  });
}

/// Process entries to compute group depths and filter collapsed groups.
///
/// In v2, groups are identified by [LogEntry.groupId] (header) and
/// [LogEntry.parentId] (child membership). There are no explicit
/// open/close group actions.
List<DisplayEntry> processGrouping({
  required List<LogEntry> entries,
  required String? textFilter,
  required Set<String> collapsedGroups,
  Set<String>? stickyOverrideIds,
  LogStore? logStore,
}) {
  // Pre-scan: collect group hierarchy and find groups with children.
  final groupIdsWithChildren = <String>{};
  final groupParents = <String, String?>{};
  for (final entry in entries) {
    if (entry.groupId != null) {
      groupParents[entry.groupId!] = entry.parentId;
    }
    if (entry.parentId != null) {
      groupIdsWithChildren.add(entry.parentId!);
    }
  }

  // Compute group depths (memoized).
  final groupDepths = <String, int>{};
  int getDepth(String groupId, [Set<String>? seen]) {
    if (groupDepths.containsKey(groupId)) return groupDepths[groupId]!;
    seen ??= {};
    if (!seen.add(groupId)) return 0; // circular-ref guard
    final parent = groupParents[groupId];
    if (parent == null) {
      groupDepths[groupId] = 0;
      return 0;
    }
    final d = getDepth(parent, seen) + 1;
    groupDepths[groupId] = d;
    return d;
  }

  for (final gid in groupParents.keys) {
    getDepth(gid);
  }

  // Check if an entry is hidden by a collapsed ancestor.
  bool isCollapsed(String? parentId) {
    var current = parentId;
    final seen = <String>{};
    while (current != null && seen.add(current)) {
      if (collapsedGroups.contains(current)) return true;
      current = groupParents[current];
    }
    return false;
  }

  final hasTextFilter = textFilter != null && textFilter.isNotEmpty;
  final result = <DisplayEntry>[];

  for (final entry in entries) {
    final isGroupHeader = entry.groupId != null;
    final parentId = entry.parentId;

    // Compute depth.
    int depth;
    if (isGroupHeader) {
      depth = groupDepths[entry.groupId] ?? 0;
    } else if (parentId != null) {
      depth = (groupDepths[parentId] ?? 0) + 1;
    } else {
      depth = 0;
    }

    // Check if hidden by collapsed ancestor.
    if (parentId != null && isCollapsed(parentId)) continue;

    // Determine sticky state — only manual pin via stickyOverrideIds.
    final isSticky = stickyOverrideIds?.contains(entry.id) ?? false;

    if (isGroupHeader) {
      final gid = entry.groupId!;
      final hasChildren = groupIdsWithChildren.contains(gid);
      result.add(
        DisplayEntry(
          entry: entry,
          depth: depth,
          stackDepth: logStore?.stackDepth(entry.id) ?? 1,
          isSticky: isSticky,
          parentGroupId: parentId,
          isStandalone: !hasChildren && hasTextFilter,
        ),
      );
    } else {
      result.add(
        DisplayEntry(
          entry: entry,
          depth: depth,
          stackDepth: logStore?.stackDepth(entry.id) ?? 1,
          isSticky: isSticky,
          parentGroupId: parentId,
        ),
      );
    }
  }

  return result;
}
