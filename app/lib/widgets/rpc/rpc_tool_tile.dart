import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/connection_manager.dart';
import '../../services/rpc_service.dart';
import '../../theme/colors.dart';
import '../../theme/constants.dart';
import '../../theme/typography.dart';

/// Displays a single RPC tool with invoke/result inline.
class RpcToolTile extends StatefulWidget {
  /// Session that owns this tool.
  final String sessionId;

  /// Tool method name.
  final String toolName;

  /// Human-readable description.
  final String description;

  /// Category: 'getter' or 'tool'.
  final String category;

  /// Optional JSON-Schema describing accepted arguments.
  final Map<String, dynamic>? argsSchema;

  /// Whether to show a confirmation dialog before invoking.
  final bool requiresConfirm;

  const RpcToolTile({
    super.key,
    required this.sessionId,
    required this.toolName,
    required this.description,
    required this.category,
    this.argsSchema,
    this.requiresConfirm = false,
  });

  @override
  State<RpcToolTile> createState() => _RpcToolTileState();
}

class _RpcToolTileState extends State<RpcToolTile> {
  bool _loading = false;
  dynamic _result;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: _loading ? null : _onInvoke,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: LoggerColors.bgSurface,
                borderRadius: kBorderRadius,
                border: Border.all(color: LoggerColors.borderSubtle),
              ),
              child: Row(
                children: [
                  Icon(
                    widget.category == 'getter'
                        ? Icons.download
                        : Icons.build_outlined,
                    size: 14,
                    color: LoggerColors.fgMuted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.toolName,
                          style: LoggerTypography.headerBtn,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (widget.description.isNotEmpty)
                          Text(
                            widget.description,
                            style: LoggerTypography.logMeta,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  if (_loading)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: LoggerColors.fgSecondary,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (_result != null || _error != null)
            Container(
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: LoggerColors.bgBase,
                borderRadius: kBorderRadius,
              ),
              child: Text(
                _error ?? _formatResult(_result),
                style: LoggerTypography.logBody.copyWith(
                  color: _error != null
                      ? LoggerColors.severityErrorText
                      : LoggerColors.fgPrimary,
                ),
                maxLines: 10,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _onInvoke() async {
    final rpcService = context.read<RpcService>();
    final connection = context.read<ConnectionManager>();

    if (widget.requiresConfirm) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: LoggerColors.bgOverlay,
          title: Text('Confirm', style: LoggerTypography.sectionH),
          content: Text(
            'Invoke "${widget.toolName}"?',
            style: LoggerTypography.drawer,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Invoke'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() {
      _loading = true;
      _result = null;
      _error = null;
    });

    try {
      final data = await rpcService.invoke(
        widget.sessionId,
        widget.toolName,
        null,
        connection,
      );
      if (mounted) {
        setState(() {
          _loading = false;
          _result = data;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  String _formatResult(dynamic data) {
    if (data == null) return 'null';
    if (data is String) return data;
    try {
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(data);
    } catch (e) {
      debugPrint('Warning: RPC result JSON formatting failed: $e');
      return data.toString();
    }
  }
}
