part of 'settings_panel.dart';

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
        SettingsPanelHeader(
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
        if (appVersion.isNotEmpty || commitSha.isNotEmpty) ...[
          const SizedBox(height: 16),
          Center(
            child: Opacity(
              opacity: 0.4,
              child: Text(
                [
                  if (appVersion.isNotEmpty) 'v$appVersion',
                  if (commitSha.isNotEmpty) commitSha.substring(0, 7),
                ].join(' · '),
                style: const TextStyle(
                  fontSize: kFontSizeSubhead,
                  fontFamily: 'JetBrains Mono',
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}
