import 'package:flutter/material.dart';

import '../../../models/log_entry.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';

class TableRenderer extends StatelessWidget {
  final LogEntry entry;

  const TableRenderer({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final data = entry.customData;
    if (data is! Map) {
      return Text(
        '[table: invalid data]',
        style: LoggerTypography.logBody.copyWith(color: LoggerColors.fgMuted),
      );
    }

    final columns = (data['columns'] as List?)?.cast<String>() ?? [];
    final rows =
        (data['rows'] as List?)?.map((r) => (r as List).toList()).toList() ??
        [];
    final caption = data['caption'] as String?;
    final highlightColumn = data['highlight_column'] as int?;

    if (columns.isEmpty) {
      return Text(
        '[table: no columns]',
        style: LoggerTypography.logBody.copyWith(color: LoggerColors.fgMuted),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (caption != null) ...[
          Text(
            caption,
            style: LoggerTypography.groupTitle.copyWith(
              color: LoggerColors.fgSecondary,
            ),
          ),
          const SizedBox(height: 4),
        ],
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 200),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: LoggerColors.borderSubtle),
              borderRadius: BorderRadius.circular(4),
            ),
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: DataTable(
                  headingRowHeight: 28,
                  dataRowMinHeight: 24,
                  dataRowMaxHeight: 36,
                  columnSpacing: 16,
                  horizontalMargin: 8,
                  headingRowColor: WidgetStateProperty.all(
                    LoggerColors.bgRaised,
                  ),
                  dataRowColor: WidgetStateProperty.resolveWith((states) {
                    return LoggerColors.bgSurface;
                  }),
                  border: TableBorder(
                    horizontalInside: BorderSide(
                      color: LoggerColors.borderSubtle,
                      width: 1,
                    ),
                  ),
                  columns: columns.asMap().entries.map((e) {
                    final isHighlight = e.key == highlightColumn;
                    return DataColumn(
                      label: Text(
                        e.value,
                        style: LoggerTypography.logMeta.copyWith(
                          color: isHighlight
                              ? LoggerColors.borderFocus
                              : LoggerColors.syntaxKey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }).toList(),
                  rows: rows.asMap().entries.map((rowEntry) {
                    final row = rowEntry.value;
                    final isEven = rowEntry.key.isEven;
                    return DataRow(
                      color: WidgetStateProperty.all(
                        isEven ? LoggerColors.bgSurface : LoggerColors.bgBase,
                      ),
                      cells: List.generate(columns.length, (colIdx) {
                        final cellValue = colIdx < row.length
                            ? row[colIdx]
                            : null;
                        final isHighlight = colIdx == highlightColumn;
                        return DataCell(
                          Text(
                            cellValue?.toString() ?? '',
                            style: LoggerTypography.logBody.copyWith(
                              color: isHighlight
                                  ? LoggerColors.borderFocus
                                  : LoggerColors.fgPrimary,
                            ),
                          ),
                        );
                      }),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
