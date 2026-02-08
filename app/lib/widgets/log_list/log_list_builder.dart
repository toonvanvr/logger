import '../../models/log_entry.dart';
import '../../services/log_store.dart';
import '../../services/sticky_state.dart';
import 'sticky_models.dart';

/// A display-ready entry with computed group depth and state.
class DisplayEntry {
  final LogEntry entry;
  final int depth;
  final bool isSticky;
  final String? parentGroupId;

  /// True when this group-open has no visible children (text filtering).
  final bool isStandalone;

  const DisplayEntry({
    required this.entry,
    required this.depth,
    this.isSticky = false,
    this.parentGroupId,
    this.isStandalone = false,
  });
}

/// Process entries to compute group depths and filter collapsed groups.
List<DisplayEntry> processGrouping({
  required List<LogEntry> entries,
  required String? textFilter,
  required Set<String> collapsedGroups,
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
            result.add(DisplayEntry(
              entry: entry,
              depth: depth,
              isSticky: isSticky,
              parentGroupId: parentGroupId,
              isStandalone: true,
            ));
          } else {
            result.add(DisplayEntry(
              entry: entry,
              depth: depth,
              isSticky: isSticky,
              parentGroupId: parentGroupId,
            ));
          }
        }
        groupStack.add(gid);
        depth++;
      } else if (entry.groupAction == GroupAction.close) {
        if (depth > 0) depth--;
        final closedId =
            groupStack.isNotEmpty ? groupStack.removeLast() : null;
        if (closedId != null) stickyGroupIds.remove(closedId);

        final closeHasChildren =
            closedId != null && groupIdsWithChildren.contains(closedId);
        if (!isHidden && (closeHasChildren || !hasTextFilter)) {
          result.add(DisplayEntry(
            entry: entry,
            depth: depth,
            parentGroupId: parentGroupId,
          ));
        }
      }
    } else {
      if (!isHidden) {
        final isInStickyGroup = groupStack.any(
          (gid) => stickyGroupIds.contains(gid),
        );
        final isSticky = entry.sticky == true || isInStickyGroup;
        result.add(DisplayEntry(
          entry: entry,
          depth: depth,
          isSticky: isSticky,
          parentGroupId: parentGroupId,
        ));
      }
    }
  }

  return result;
}

/// Compute sticky sections from display entries for the pinned overlay.
List<StickySection> computeStickySections(
  List<DisplayEntry> entries, {
  required int firstVisibleIndex,
  Set<String> dismissedIds = const {},
  Set<String> ignoredGroupIds = const {},
  Set<String> expandedStickyGroups = const {},
  Set<String> collapsedGroups = const {},
}) {
  final stickyEntries = entries.where((e) => e.isSticky).toList();
  if (stickyEntries.isEmpty) return [];

  final grouped = <String?, List<DisplayEntry>>{};
  for (final entry in stickyEntries) {
    if (entry.entry.type == LogType.group) continue;
    if (dismissedIds.contains(entry.entry.id)) continue;
    grouped.putIfAbsent(entry.parentGroupId, () => []).add(entry);
  }

  for (final entry in stickyEntries) {
    if (entry.entry.type == LogType.group &&
        entry.entry.groupAction == GroupAction.open) {
      final gid = entry.entry.groupId ?? entry.entry.id;
      grouped.putIfAbsent(gid, () => []);
    }
  }

  final sections = <StickySection>[];

  for (final mapEntry in grouped.entries) {
    final parentId = mapEntry.key;
    final stickyChildren = mapEntry.value;

    if (parentId != null && ignoredGroupIds.contains(parentId)) continue;

    LogEntry? groupHeader;
    int hiddenCount = 0;
    int groupDepth = 0;
    int groupHeaderIndex = -1;

    if (parentId != null) {
      for (int i = 0; i < entries.length; i++) {
        final d = entries[i];
        if (d.entry.type == LogType.group &&
            d.entry.groupAction == GroupAction.open &&
            (d.entry.groupId ?? d.entry.id) == parentId) {
          groupHeader = d.entry;
          groupDepth = d.depth;
          groupHeaderIndex = i;
          break;
        }
      }

      if (!collapsedGroups.contains(parentId) &&
          groupHeaderIndex >= firstVisibleIndex) {
        continue;
      }

      hiddenCount = entries
          .where((d) =>
              d.parentGroupId == parentId &&
              !d.isSticky &&
              d.entry.type != LogType.group)
          .length;
    }

    final visibleStickyChildren = <DisplayEntry>[];
    for (final child in stickyChildren) {
      final idx = entries.indexOf(child);
      if (idx < firstVisibleIndex) {
        visibleStickyChildren.add(child);
      }
    }

    List<LogEntry> sectionEntries;
    if (parentId != null && expandedStickyGroups.contains(parentId)) {
      final allGroupEntries = entries
          .where((d) =>
              d.parentGroupId == parentId &&
              d.entry.type != LogType.group &&
              !dismissedIds.contains(d.entry.id))
          .take(10)
          .map((d) => d.entry)
          .toList();
      sectionEntries = allGroupEntries;
      final totalInGroup = entries
          .where((d) =>
              d.parentGroupId == parentId &&
              d.entry.type != LogType.group &&
              !dismissedIds.contains(d.entry.id))
          .length;
      hiddenCount = totalInGroup > 10 ? totalInGroup - 10 : 0;
    } else {
      sectionEntries = visibleStickyChildren.map((d) => d.entry).toList();
    }

    if (sectionEntries.isNotEmpty || groupHeader != null) {
      sections.add(StickySection(
        groupHeader: groupHeader,
        entries: sectionEntries,
        hiddenCount: hiddenCount,
        groupDepth: groupDepth,
      ));
    }
  }

  return sections;
}

/// Auto-dismiss entries that arrive with sticky_action: 'unpin'.
void processUnpinEntries({
  required LogStore logStore,
  required StickyStateService stickyState,
  required Set<String> processedUnpinIds,
}) {
  final groupsToIgnore = <String>[];
  final idsToDismiss = <String>[];

  for (final entry in logStore.entries) {
    if (entry.stickyAction == 'unpin' &&
        !processedUnpinIds.contains(entry.id)) {
      processedUnpinIds.add(entry.id);
      final groupId = entry.groupId;
      if (groupId != null) groupsToIgnore.add(groupId);
      idsToDismiss.add(entry.id);
    }
  }

  if (groupsToIgnore.isNotEmpty || idsToDismiss.isNotEmpty) {
    for (final gid in groupsToIgnore) {
      stickyState.ignore(gid);
    }
    for (final id in idsToDismiss) {
      stickyState.dismiss(id);
    }
  }
}
