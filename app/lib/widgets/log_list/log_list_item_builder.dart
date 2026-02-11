part of 'log_list_view.dart';

/// Check if shift key is currently held (for range selection).
bool _isShiftHeld() {
  return HardwareKeyboard.instance.logicalKeysPressed.contains(
        LogicalKeyboardKey.shiftLeft,
      ) ||
      HardwareKeyboard.instance.logicalKeysPressed.contains(
        LogicalKeyboardKey.shiftRight,
      );
}

/// Item building, group collapse, and stack expansion state for the log list.
mixin _LogListItemBuilderMixin on State<LogListView> {
  final Set<String> _seenEntryIds = {};
  final Set<String> _collapsedGroups = {};
  final Set<String> _autoCollapsedSeen = {};
  final Set<String> _expandedStacks = {};
  final Map<String, int> _stackActiveIndices = {};
  final Set<String> _processedUnpinIds = {};
  List<DisplayEntry> _currentDisplayEntries = [];
  int _selectedIndex = -1;

  Widget _buildItem(DisplayEntry display, int index, LogStore logStore) {
    final entry = display.entry;
    final isNew = _seenEntryIds.add(entry.id);
    final isExpanded = _expandedStacks.contains(entry.id);
    final row = LogRow(
      key: ValueKey(entry.id),
      entry: entry,
      isNew: isNew,
      isEvenRow: index.isEven,
      isSelected: _selectedIndex == index,
      selectionMode: widget.selectionMode,
      isSelectionSelected: widget.selectedEntryIds.contains(entry.id),
      onSelect: () {
        if (widget.selectionMode && _isShiftHeld()) {
          final orderedIds =
              _currentDisplayEntries.map((e) => e.entry.id).toList();
          widget.onEntryRangeSelected?.call(entry.id, orderedIds);
        } else {
          widget.onEntrySelected?.call(entry.id);
        }
      },
      isBookmarked: widget.bookmarkedEntryIds.contains(entry.id),
      groupDepth: display.depth,
      showGroupChevron:
          !widget.flatMode &&
          entry.groupId != null &&
          entry.id == entry.groupId &&
          !display.isStandalone,
      stackDepth: display.stackDepth,
      onStackToggle: display.stackDepth > 1
          ? () => setState(() {
              if (_expandedStacks.contains(entry.id)) {
                _expandedStacks.remove(entry.id);
                _stackActiveIndices.remove(entry.id);
              } else {
                _expandedStacks.add(entry.id);
                final stack = logStore.getStack(entry.id);
                _stackActiveIndices[entry.id] = stack.length - 1;
              }
            })
          : null,
      onTap: () {
        setState(() {
          _selectedIndex = _selectedIndex == index ? -1 : index;
        });
      },
      onGroupToggle:
          !widget.flatMode &&
              entry.groupId != null &&
              entry.id == entry.groupId &&
              !display.isStandalone
          ? () => setState(() {
              final gid = entry.groupId!;
              _collapsedGroups.contains(gid)
                  ? _collapsedGroups.remove(gid)
                  : _collapsedGroups.add(gid);
            })
          : null,
      isCollapsed:
          entry.groupId != null &&
          entry.id == entry.groupId &&
          !display.isStandalone &&
          _collapsedGroups.contains(entry.groupId!),
    );

    if (!isExpanded) return row;

    final stack = logStore.getStack(entry.id);
    final activeIdx = _stackActiveIndices[entry.id] ?? (stack.length - 1);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        row,
        StackExpansionPanel(
          stack: stack,
          activeIndex: activeIdx,
          onVersionSelected: (i) => setState(() {
            _stackActiveIndices[entry.id] = i;
          }),
        ),
      ],
    );
  }
}
