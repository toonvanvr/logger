import 'package:flutter/material.dart';

import '../../plugins/plugin_registry.dart';
import '../../plugins/plugin_types.dart';
import '../../theme/colors.dart';
import '../../version.dart';
import 'connection_settings.dart';
import 'settings_panel_header.dart';
import 'settings_sub_panels.dart';
import 'tool_group.dart';
import 'tool_row.dart';

/// Slide-out settings sidebar with grouped plugin tools.
class SettingsPanel extends StatefulWidget {
  final bool isVisible;
  final VoidCallback onClose;

  const SettingsPanel({
    super.key,
    required this.isVisible,
    required this.onClose,
  });

  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _isRendered = false;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.dismissed) {
        setState(() => _isRendered = false);
      }
    });
    if (widget.isVisible) {
      _isRendered = true;
      _controller.value = 1.0;
    }
  }
  @override
  void didUpdateWidget(covariant SettingsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible && !oldWidget.isVisible) {
      setState(() => _isRendered = true);
      _controller.forward();
    } else if (!widget.isVisible && oldWidget.isVisible) {
      _controller.reverse();
    }
  }
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    if (!_isRendered) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => ClipRect(
        child: Align(
          alignment: Alignment.centerRight,
          widthFactor: _controller.value,
          child: child,
        ),
      ),
      child: SizedBox(
        width: 300,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: LoggerColors.bgRaised,
            border: Border(
              left: BorderSide(color: LoggerColors.borderSubtle, width: 1),
            ),
          ),
          child: _PanelContent(onClose: widget.onClose),
        ),
      ),
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
                  fontSize: 11,
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


