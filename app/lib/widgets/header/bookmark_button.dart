import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/query_store.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';

/// Bookmark icon button that shows saved queries in a popup menu.
class BookmarkButton extends StatelessWidget {
  final Set<String> activeSeverities;
  final String textFilter;
  final ValueChanged<SavedQuery> onQueryLoaded;

  const BookmarkButton({
    super.key,
    required this.activeSeverities,
    required this.textFilter,
    required this.onQueryLoaded,
  });

  @override
  Widget build(BuildContext context) {
    final hasQueries = context.select<QueryStore, bool>(
      (s) => s.queries.isNotEmpty,
    );

    return PopupMenuButton<BookmarkAction>(
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      tooltip: 'Saved queries',
      icon: Icon(
        hasQueries ? Icons.bookmark : Icons.bookmark_border,
        size: 16,
        color: LoggerColors.fgMuted,
      ),
      iconSize: 16,
      color: LoggerColors.bgOverlay,
      onSelected: (action) => _handleAction(context, action),
      itemBuilder: (_) => _buildMenuItems(context.read<QueryStore>()),
    );
  }

  List<PopupMenuEntry<BookmarkAction>> _buildMenuItems(QueryStore queryStore) {
    final items = <PopupMenuEntry<BookmarkAction>>[];

    // Save current option
    items.add(
      PopupMenuItem(
        value: BookmarkAction.save,
        child: Row(
          children: [
            const Icon(Icons.save, size: 14, color: LoggerColors.fgSecondary),
            const SizedBox(width: 8),
            Text(
              'Save current filters',
              style: LoggerTypography.logMeta.copyWith(
                color: LoggerColors.fgPrimary,
              ),
            ),
          ],
        ),
      ),
    );

    if (queryStore.queries.isNotEmpty) {
      items.add(const PopupMenuDivider(height: 1));

      for (var i = 0; i < queryStore.queries.length; i++) {
        final query = queryStore.queries[i];
        items.add(
          PopupMenuItem(
            value: BookmarkAction.load(i),
            child: Text(
              query.name,
              style: LoggerTypography.logMeta.copyWith(
                color: LoggerColors.fgPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      }
    }

    return items;
  }

  void _handleAction(BuildContext context, BookmarkAction action) {
    final queryStore = context.read<QueryStore>();

    switch (action) {
      case BookmarkSave():
        _showSaveDialog(context, queryStore);
      case BookmarkLoad(:final index):
        if (index < queryStore.queries.length) {
          final query = queryStore.queries[index];
          queryStore.loadQuery(query);
          onQueryLoaded(query);
        }
    }
  }

  void _showSaveDialog(BuildContext context, QueryStore queryStore) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: LoggerColors.bgOverlay,
        title: Text(
          'Save Query',
          style: LoggerTypography.logMeta.copyWith(
            color: LoggerColors.fgPrimary,
            fontSize: 14,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: LoggerTypography.logMeta.copyWith(
            color: LoggerColors.fgPrimary,
          ),
          decoration: InputDecoration(
            hintText: 'Query name',
            hintStyle: LoggerTypography.logMeta.copyWith(
              color: LoggerColors.fgMuted,
            ),
          ),
          onSubmitted: (name) {
            if (name.trim().isNotEmpty) {
              queryStore.saveQuery(
                name.trim(),
                severities: activeSeverities,
                textFilter: textFilter,
              );
              Navigator.of(ctx).pop();
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: LoggerTypography.logMeta.copyWith(
                color: LoggerColors.fgMuted,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                queryStore.saveQuery(
                  name,
                  severities: activeSeverities,
                  textFilter: textFilter,
                );
                Navigator.of(ctx).pop();
              }
            },
            child: Text(
              'Save',
              style: LoggerTypography.logMeta.copyWith(
                color: LoggerColors.borderFocus,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Action type for the bookmark popup menu.
sealed class BookmarkAction {
  const BookmarkAction();
  static const save = BookmarkSave();
  static BookmarkLoad load(int index) => BookmarkLoad(index);
}

class BookmarkSave extends BookmarkAction {
  const BookmarkSave();
}

class BookmarkLoad extends BookmarkAction {
  final int index;
  const BookmarkLoad(this.index);
}
