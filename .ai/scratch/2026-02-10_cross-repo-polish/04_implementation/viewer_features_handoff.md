# Viewer Group Features — Handoff

**Status:** COMPLETE
**Confidence:** HIGH
**Branch:** `vibe/viewer-group-features`
**Commit:** `vibe(viewer): add auto-collapse groups and duration badge features`

## Files Modified

| File | Change |
|------|--------|
| `app/lib/widgets/log_list/log_list_builder.dart` | Added `autoCollapseGroups()` pure function (18 lines) |
| `app/lib/widgets/log_list/log_list_view.dart` | Added `_autoCollapsedSeen` set + pre-scan call before `processGrouping` |
| `app/lib/widgets/log_list/log_row_content.dart` | Added `_DurationBadge` widget + wired into group header Row |
| `app/test/widgets/log_list/log_list_builder_test.dart` | 7 new tests for `autoCollapseGroups` |
| `app/test/widgets/log_list/log_row_content_test.dart` | 6 new widget tests for duration badge |

## Feature 1: Default-Collapsed Groups

- `autoCollapseGroups()` scans `filteredEntries` for group headers (`id == groupId`) with `labels['_collapsed'] == 'true'`
- Uses `seenGroupIds` set to process each group only once — user can expand and it won't re-collapse
- Called in `_LogListViewState.build()` before `processGrouping()` so the collapse set is populated in time

## Feature 2: Group Duration Badge

- `_DurationBadge` widget reads `labels['_duration_ms']` from group header entries
- Color thresholds: green (#A8CC7E) < 100ms, amber (#E6B455) < 500ms, red (#E06C60) >= 500ms
- Background: badge color at 15% alpha (`.withAlpha(38)`)
- Typography: Inter 9dp Bold, matching UX spec badge font
- Pill shape: `BorderRadius.circular(3)` (kBorderRadiusSm)
- Group header Row changed from `MainAxisSize.min` to `Expanded` label + right-aligned badge

## Test Results

- `log_list_builder_test.dart`: 22 tests pass (15 existing + 7 new)
- `log_row_content_test.dart`: 15 tests pass (9 existing + 6 new)
- All files under 300-line limit (187, 286, 266)

## Success Criteria

- [x] `autoCollapseGroups()` pure function extracts auto-collapse logic
- [x] Groups with `_collapsed: "true"` are auto-collapsed on first encounter
- [x] User can manually expand auto-collapsed groups (toggle works)
- [x] Duration badge renders on group headers with `_duration_ms` label
- [x] Duration badge uses correct colors: green < 100ms, amber < 500ms, red >= 500ms
- [x] Duration badge follows design system (Inter 9dp bold, pill shape, 15% alpha bg)
- [x] All existing tests pass
- [x] New tests for both features
- [x] Changes committed on `vibe/viewer-group-features` branch
