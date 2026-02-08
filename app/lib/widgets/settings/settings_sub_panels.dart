import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/rpc_service.dart';
import '../../services/settings_service.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';
import '../rpc/rpc_tool_tile.dart';
import 'settings_text_field.dart';

// ─── Editor config sub-panel ─────────────────────────────────────────

/// Editor settings (file/URL open commands).
class EditorSubPanel extends StatelessWidget {
  const EditorSubPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    return Padding(
      key: const ValueKey('editor'),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'File open command',
            style: LoggerTypography.logMeta.copyWith(
              color: LoggerColors.fgMuted,
            ),
          ),
          const SizedBox(height: 4),
          SettingsTextField(
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
          SettingsTextField(
            value: settings.urlOpenCommand,
            onChanged: settings.setUrlOpenCommand,
          ),
        ],
      ),
    );
  }
}

// ─── RPC tools sub-panel ─────────────────────────────────────────────

/// RPC tools grouped by session.
class RpcToolsSubPanel extends StatelessWidget {
  const RpcToolsSubPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final rpcService = context.watch<RpcService>();
    final toolsBySession = rpcService.tools;

    if (toolsBySession.isEmpty) {
      return Padding(
        key: const ValueKey('rpc-empty'),
        padding: const EdgeInsets.all(12),
        child: Text('No tools available', style: LoggerTypography.logMeta),
      );
    }

    return ListView(
      key: const ValueKey('rpc'),
      padding: const EdgeInsets.only(top: 4),
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
