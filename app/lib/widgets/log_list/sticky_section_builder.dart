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
    // Skip group headers (self-referencing groupId)
    if (entry.entry.groupId != null && entry.entry.id == entry.entry.groupId) {
      continue;
    }
    if (dismissedIds.contains(entry.entry.id)) continue;
    grouped.putIfAbsent(entry.parentGroupId, () => []).add(entry);
  }

  for (final entry in stickyEntries) {
    if (entry.entry.groupId != null && entry.entry.id == entry.entry.groupId) {
      final gid = entry.entry.groupId!;
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
        if (d.entry.groupId != null &&
            d.entry.id == d.entry.groupId &&
            d.entry.groupId == parentId) {
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
                !(d.entry.groupId != null && d.entry.id == d.entry.groupId),
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
                !(d.entry.groupId != null && d.entry.id == d.entry.groupId) &&
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
                !(d.entry.groupId != null && d.entry.id == d.entry.groupId) &&
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

/// Process unpin control entries to remove sticky state.
///
/// Scroll-aware: only processes unpin entries the user has scrolled past
/// (display index < [firstVisibleIndex]). In live mode all unpins are
/// processed immediately so tailing behaviour is preserved.
void processUnpinEntries({
  required LogStore logStore,
  required StickyStateService stickyState,
  required Set<String> processedUnpinIds,
  required List<DisplayEntry> displayEntries,
  required int firstVisibleIndex,
  required bool isLiveMode,
}) {
  for (int i = 0; i < displayEntries.length; i++) {
    final entry = displayEntries[i].entry;
    if (processedUnpinIds.contains(entry.id)) continue;
    final action = entry.labels?['_sticky_action'];
    if (action == 'unpin') {
      // In live mode, process all unpins immediately.
      // Otherwise, only process unpins the user has scrolled past.
      if (isLiveMode || i < firstVisibleIndex) {
        processedUnpinIds.add(entry.id);
        final targetId = entry.groupId ?? entry.id;
        if (targetId.isNotEmpty) {
          stickyState.dismiss(targetId);
        }
      }
    }
  }
}
