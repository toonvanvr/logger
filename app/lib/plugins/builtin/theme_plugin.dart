import 'package:flutter/material.dart';

import '../../theme/colors.dart';
import '../../theme/typography.dart';
import '../plugin_manifest.dart';
import '../plugin_registry.dart';
import '../plugin_types.dart';

/// Tool plugin for theming configuration.
///
/// Provides a settings panel for selecting the active color scheme.
/// Always present (not disableable).
class ThemePlugin extends ToolPlugin {
  final bool _enabled = true;
  String _activeTheme = 'Ayu Dark';

  static const _availableThemes = ['Ayu Dark'];

  // ─── Identity ──────────────────────────────────────────────────────

  @override
  String get id => 'dev.logger.theme';

  @override
  String get name => 'Theme';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Color scheme configuration for the viewer.';

  @override
  bool get enabled => _enabled;

  @override
  PluginManifest get manifest => const PluginManifest(
    id: 'dev.logger.theme',
    name: 'Theme',
    version: '1.0.0',
    description: 'Color scheme configuration for the viewer.',
    types: ['tool'],
    group: ToolGroups.tools,
    hasConfigPanel: true,
    disableable: false,
  );

  // ─── Tool ──────────────────────────────────────────────────────────

  @override
  String get toolLabel => 'Theme';

  @override
  IconData get toolIcon => Icons.palette_outlined;

  @override
  void onRegister(PluginRegistry registry) {}

  @override
  void onDispose() {}

  // ─── Panels ────────────────────────────────────────────────────────

  @override
  Widget buildToolPanel(BuildContext context) {
    return _ThemeConfigPanel(
      activeTheme: _activeTheme,
      themes: _availableThemes,
      onThemeChanged: (t) => _activeTheme = t,
    );
  }

  @override
  Widget buildConfigPanel(BuildContext context) => buildToolPanel(context);
}

// ─── Config panel ────────────────────────────────────────────────────

class _ThemeConfigPanel extends StatelessWidget {
  final String activeTheme;
  final List<String> themes;
  final ValueChanged<String> onThemeChanged;

  const _ThemeConfigPanel({
    required this.activeTheme,
    required this.themes,
    required this.onThemeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Color Scheme',
            style: LoggerTypography.logMeta.copyWith(
              color: LoggerColors.fgSecondary,
            ),
          ),
        ),
        for (final theme in themes)
          ListTile(
            dense: true,
            leading: Icon(
              theme == activeTheme
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 16,
              color: theme == activeTheme
                  ? LoggerColors.borderFocus
                  : LoggerColors.fgMuted,
            ),
            title: Text(
              theme,
              style: LoggerTypography.logMeta.copyWith(
                color: LoggerColors.fgPrimary,
              ),
            ),
            onTap: () => onThemeChanged(theme),
          ),
      ],
    );
  }
}
