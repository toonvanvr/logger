import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/rpc_service.dart';
import '../../theme/colors.dart';
import '../../theme/constants.dart';
import '../../theme/typography.dart';
import 'rpc_tool_tile.dart';

/// Slide-out panel for browsing and invoking RPC tools.
class RpcPanel extends StatelessWidget {
  /// Whether the panel is visible.
  final bool isVisible;

  /// Called when the close button is pressed.
  final VoidCallback onClose;

  const RpcPanel({super.key, required this.isVisible, required this.onClose});

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
        Expanded(child: _ToolList()),
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
      padding: kHPadding12,
      child: Row(
        children: [
          Text('Tools', style: LoggerTypography.sectionH),
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

class _ToolList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final rpcService = context.watch<RpcService>();
    final toolsBySession = rpcService.tools;

    if (toolsBySession.isEmpty) {
      return Center(
        child: Text('No tools available', style: LoggerTypography.logMeta),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 4),
      children: [
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
    );
  }
}
