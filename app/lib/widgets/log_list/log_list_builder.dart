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
/// In v2, group headers have `id == groupId` (self-referencing),
/// group children carry `groupId` pointing to their enclosing group,
/// and group-close sentinels have `groupId` set with empty message.
List<DisplayEntry> processGrouping({
  required List<LogEntry> entries,
  required String? textFilter,
  required Set<String> collapsedGroups,
  Set<String>? stickyOverrideIds,
  LogStore? logStore,
}) {
  // Pre-scan: build group hierarchy using entry-order stack approach.
  final groupStack = <String>[];
  final groupParents = <String, String?>{};
  final groupIdsWithChildren = <String>{};

  for (final entry in entries) {
    // Skip control messages in pre-scan.
    if (entry.labels != null && entry.labels!['_sticky_action'] == 'unpin') {
      continue;
    }
    final isHeader = entry.groupId != null && entry.id == entry.groupId;
    final isClose =
        entry.groupId != null &&
        entry.id != entry.groupId &&
        (entry.message == null || entry.message == '');

    if (isHeader) {
      groupParents[entry.groupId!] = groupStack.isNotEmpty
          ? groupStack.last
          : null;
      groupStack.add(entry.groupId!);
      if (groupStack.length > 1) {
        groupIdsWithChildren.add(groupStack[groupStack.length - 2]);
      }
    } else if (isClose) {
      if (groupStack.isNotEmpty && groupStack.last == entry.groupId) {
        groupStack.removeLast();
      }
    } else if (entry.groupId != null) {
      groupIdsWithChildren.add(entry.groupId!);
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
    final isGroupHeader = entry.groupId != null && entry.id == entry.groupId;
    final isGroupClose =
        !isGroupHeader &&
        entry.groupId != null &&
        (entry.message == null || entry.message == '');

    // Skip group-close sentinel entries.
    if (isGroupClose) continue;

    // Skip unpin control messages.
    if (entry.labels != null && entry.labels!['_sticky_action'] == 'unpin') {
      continue;
    }

    // Compute depth.
    int depth;
    if (isGroupHeader) {
      depth = groupDepths[entry.groupId] ?? 0;
    } else if (entry.groupId != null) {
      depth = (groupDepths[entry.groupId] ?? 0) + 1;
    } else {
      depth = 0;
    }

    // Check collapsed — headers check parent, members check their group.
    final parentGid = isGroupHeader
        ? groupParents[entry.groupId]
        : entry.groupId;
    if (parentGid != null && isCollapsed(parentGid)) continue;

    // Sticky: check both manual override AND server labels.
    final isSticky =
        (stickyOverrideIds?.contains(entry.id) ?? false) ||
        (entry.labels != null && entry.labels!['_sticky'] == 'true');

    if (isGroupHeader) {
      final gid = entry.groupId!;
      final hasChildren = groupIdsWithChildren.contains(gid);
      result.add(
        DisplayEntry(
          entry: entry,
          depth: depth,
          stackDepth: logStore?.stackDepth(entry.id) ?? 1,
          isSticky: isSticky,
          parentGroupId: groupParents[entry.groupId],
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
          parentGroupId: entry.groupId,
        ),
      );
    }
  }

  return result;
}
