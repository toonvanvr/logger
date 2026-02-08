import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/rpc_service.dart';
import '../../services/settings_service.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';
import '../rpc/rpc_tool_tile.dart';

/// Slide-out settings sidebar with editor configuration and RPC tools.
class SettingsPanel extends StatelessWidget {
  /// Whether the panel is visible.
  final bool isVisible;

  /// Called when the close button is pressed.
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

class _PanelContent extends StatelessWidget {
  final VoidCallback onClose;

  const _PanelContent({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PanelHeader(onClose: onClose),
        const Divider(height: 1, color: LoggerColors.borderSubtle),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 4),
            children: const [
              _EditorSettingsSection(),
              Divider(height: 1, color: LoggerColors.borderSubtle),
              _RpcToolsSection(),
            ],
          ),
        ),
      ],
    );
  }
}

class _PanelHeader extends StatelessWidget {
  final VoidCallback onClose;

  const _PanelHeader({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Text('Settings', style: LoggerTypography.sectionH),
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

// ─── Editor Settings ─────────────────────────────────────────────────

class _EditorSettingsSection extends StatelessWidget {
  const _EditorSettingsSection();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Editor',
            style: LoggerTypography.sectionH.copyWith(
              color: LoggerColors.fgSecondary,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'File open command',
            style: LoggerTypography.logMeta.copyWith(
              color: LoggerColors.fgMuted,
            ),
          ),
          const SizedBox(height: 4),
          _SettingsTextField(
            value: settings.fileOpenCommand,
            onChanged: settings.setFileOpenCommand,
          ),
          const SizedBox(height: 8),
          Text(
            'URL open command',
            style: LoggerTypography.logMeta.copyWith(
              color: LoggerColors.fgMuted,
            ),
          ),
          const SizedBox(height: 4),
          _SettingsTextField(
            value: settings.urlOpenCommand,
            onChanged: settings.setUrlOpenCommand,
          ),
        ],
      ),
    );
  }
}

class _SettingsTextField extends StatefulWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _SettingsTextField({required this.value, required this.onChanged});

  @override
  State<_SettingsTextField> createState() => _SettingsTextFieldState();
}

class _SettingsTextFieldState extends State<_SettingsTextField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(_SettingsTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && _controller.text != widget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      style: LoggerTypography.logMeta.copyWith(color: LoggerColors.fgPrimary),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        filled: true,
        fillColor: LoggerColors.bgSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: LoggerColors.borderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: LoggerColors.borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: LoggerColors.borderFocus),
        ),
      ),
      onChanged: widget.onChanged,
    );
  }
}

// ─── RPC Tools ───────────────────────────────────────────────────────

class _RpcToolsSection extends StatelessWidget {
  const _RpcToolsSection();

  @override
  Widget build(BuildContext context) {
    final rpcService = context.watch<RpcService>();
    final toolsBySession = rpcService.tools;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'RPC Tools',
              style: LoggerTypography.sectionH.copyWith(
                color: LoggerColors.fgSecondary,
                fontSize: 11,
              ),
            ),
          ),
          if (toolsBySession.isEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'No tools available',
                style: LoggerTypography.logMeta,
              ),
            )
          else
            for (final entry in toolsBySession.entries) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: Text(
                  entry.key,
                  style: LoggerTypography.badge.copyWith(
                    color: LoggerColors.fgMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              for (final tool in entry.value)
                RpcToolTile(
                  sessionId: entry.key,
                  toolName: tool.name,
                  description: tool.description,
                  category: tool.category,
                  argsSchema: tool.argsSchema,
                  requiresConfirm: tool.confirm,
                ),
            ],
        ],
      ),
    );
  }
}
