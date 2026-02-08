import 'package:flutter/material.dart';

import '../../plugins/plugin_registry.dart';
import '../../plugins/plugin_types.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';
import 'connection_settings.dart';
import 'settings_sub_panels.dart';
import 'tool_group.dart';
import 'tool_row.dart';

/// Slide-out settings sidebar with grouped plugin tools.
class SettingsPanel extends StatelessWidget {
  final bool isVisible;
  final VoidCallback onClose;

  const SettingsPanel({
    super.key,
    required this.isVisible,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: isVisible ? 300 : 0,
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(
        color: LoggerColors.bgRaised,
        border: Border(
          left: BorderSide(color: LoggerColors.borderSubtle, width: 1),
        ),
      ),
      child: isVisible ? _PanelContent(onClose: onClose) : null,
    );
  }
}

// ─── Internal widgets ────────────────────────────────────────────────

class _PanelContent extends StatefulWidget {
  final VoidCallback onClose;
  const _PanelContent({required this.onClose});

  @override
  State<_PanelContent> createState() => _PanelContentState();
}

class _PanelContentState extends State<_PanelContent> {
  Widget? _subPanel;
  String? _subPanelTitle;

  void _openSubPanel(String title, Widget panel) {
    setState(() {
      _subPanelTitle = title;
      _subPanel = panel;
    });
  }

  void _closeSubPanel() {
    setState(() {
      _subPanel = null;
      _subPanelTitle = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PanelHeader(
          title: _subPanelTitle ?? 'Settings',
          showBack: _subPanel != null,
          onBack: _closeSubPanel,
          onClose: widget.onClose,
        ),
        const Divider(height: 1, color: LoggerColors.borderSubtle),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            child: _subPanel ?? _buildMainList(),
          ),
        ),
      ],
    );
  }

  Widget _buildMainList() {
    final registry = PluginRegistry.instance;
    final filters = registry.getPlugins<FilterPlugin>();
    final renderers = registry.getPlugins<RendererPlugin>();
    final transforms = registry.getPlugins<TransformPlugin>();

    return ListView(
      key: const ValueKey('main'),
      padding: const EdgeInsets.symmetric(vertical: 4),
      children: [
        ToolGroup(
          title: ToolGroups.connections,
          children: [
            ToolRow(
              icon: Icons.cable,
              label: 'Connections',
              hasConfig: true,
              onConfigTap: () =>
                  _openSubPanel('Connections', const ConnectionSettings()),
            ),
          ],
        ),
        if (filters.isNotEmpty)
          ToolGroup(
            title: ToolGroups.searchFilter,
            children: [
              for (final p in filters)
                ToolRow(
                  icon: p.filterIcon,
                  label: p.name,
                  enabled: p.manifest.disableable ? p.enabled : null,
                  onEnabledChanged: p.manifest.disableable
                      ? (v) => setState(() => registry.setEnabled(p.id, v))
                      : null,
                ),
            ],
          ),
        if (renderers.isNotEmpty)
          ToolGroup(
            title: ToolGroups.renderers,
            children: [
              for (final p in renderers)
                ToolRow(
                  icon: Icons.brush,
                  label: p.name,
                  enabled: p.manifest.disableable ? p.enabled : null,
                  onEnabledChanged: p.manifest.disableable
                      ? (v) => setState(() => registry.setEnabled(p.id, v))
                      : null,
                ),
            ],
          ),
        if (transforms.isNotEmpty)
          ToolGroup(
            title: ToolGroups.transforms,
            children: [
              for (final p in transforms)
                ToolRow(
                  icon: Icons.transform,
                  label: p.name,
                  enabled: p.manifest.disableable ? p.enabled : null,
                  onEnabledChanged: p.manifest.disableable
                      ? (v) => setState(() => registry.setEnabled(p.id, v))
                      : null,
                ),
            ],
          ),
        ToolGroup(
          title: ToolGroups.tools,
          children: [
            ToolRow(
              icon: Icons.edit,
              label: 'Editor',
              hasConfig: true,
              onConfigTap: () =>
                  _openSubPanel('Editor', const EditorSubPanel()),
            ),
            ToolRow(
              icon: Icons.terminal,
              label: 'RPC Tools',
              hasConfig: true,
              onConfigTap: () =>
                  _openSubPanel('RPC Tools', const RpcToolsSubPanel()),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Panel header with optional back button ──────────────────────────

class _PanelHeader extends StatelessWidget {
  final String title;
  final bool showBack;
  final VoidCallback onBack;
  final VoidCallback onClose;

  const _PanelHeader({
    required this.title,
    required this.showBack,
    required this.onBack,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          if (showBack)
            InkWell(
              onTap: onBack,
              child: const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(
                  Icons.arrow_back,
                  size: 16,
                  color: LoggerColors.fgSecondary,
                ),
              ),
            ),
          Text(title, style: LoggerTypography.sectionH),
          const Spacer(),
          InkWell(
            onTap: onClose,
            child: const Icon(
              Icons.close,
              size: 16,
              color: LoggerColors.fgSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
