import 'package:flutter/material.dart';

import '../../theme/colors.dart';
import '../../theme/typography.dart';

/// Tabs for filtering logs by section (State, Events, custom sections).
///
/// Sections appear only when logs with that section name have been received.
class SectionTabs extends StatelessWidget {
  final List<String> sections;
  final String? selectedSection;
  final ValueChanged<String?> onSectionChanged;

  const SectionTabs({
    super.key,
    required this.sections,
    required this.selectedSection,
    required this.onSectionChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (sections.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 28,
      color: LoggerColors.bgRaised,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          _SectionTab(
            label: 'ALL',
            isSelected: selectedSection == null,
            onTap: () => onSectionChanged(null),
          ),
          for (final section in sections)
            _SectionTab(
              label: section.toUpperCase(),
              isSelected: selectedSection == section,
              onTap: () => onSectionChanged(section),
            ),
        ],
      ),
    );
  }
}

class _SectionTab extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SectionTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? LoggerColors.borderFocus : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: LoggerTypography.sectionH.copyWith(
            color: isSelected
                ? LoggerColors.fgPrimary
                : LoggerColors.fgSecondary,
          ),
        ),
      ),
    );
  }
}
