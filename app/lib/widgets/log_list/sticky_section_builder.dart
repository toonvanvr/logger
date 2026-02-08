import '../../models/log_entry.dart';
import '../../services/log_store.dart';
import '../../services/sticky_state.dart';
import 'log_list_builder.dart';
import 'sticky_models.dart';

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
          .where(
            (d) =>
                d.parentGroupId == parentId &&
                !d.isSticky &&
                d.entry.type != LogType.group,
          )
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
          .where(
            (d) =>
                d.parentGroupId == parentId &&
                d.entry.type != LogType.group &&
                !dismissedIds.contains(d.entry.id),
          )
          .take(10)
          .map((d) => d.entry)
          .toList();
      sectionEntries = allGroupEntries;
      final totalInGroup = entries
          .where(
            (d) =>
                d.parentGroupId == parentId &&
                d.entry.type != LogType.group &&
                !dismissedIds.contains(d.entry.id),
          )
          .length;
      hiddenCount = totalInGroup > 10 ? totalInGroup - 10 : 0;
    } else {
      sectionEntries = visibleStickyChildren.map((d) => d.entry).toList();
    }

    if (sectionEntries.isNotEmpty || groupHeader != null) {
      sections.add(
        StickySection(
          groupHeader: groupHeader,
          entries: sectionEntries,
          hiddenCount: hiddenCount,
          groupDepth: groupDepth,
        ),
      );
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
