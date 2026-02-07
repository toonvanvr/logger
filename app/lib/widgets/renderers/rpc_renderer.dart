import 'dart:convert';

import 'package:flutter/material.dart';

import '../../models/log_entry.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';

/// Renders an RPC log entry (request, response, or error).
class RpcRenderer extends StatelessWidget {
  final LogEntry entry;

  const RpcRenderer({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final direction = entry.rpcDirection ?? RpcDirection.request;

    return switch (direction) {
      RpcDirection.request => _buildRequest(),
      RpcDirection.response => _buildResponse(),
      RpcDirection.error => _buildError(),
    };
  }

  Widget _buildRequest() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '→ ',
                style: LoggerTypography.logBody.copyWith(
                  color: LoggerColors.syntaxKey,
                ),
              ),
              TextSpan(
                text: entry.rpcMethod ?? 'unknown',
                style: LoggerTypography.logBody.copyWith(
                  color: LoggerColors.fgPrimary,
                ),
              ),
            ],
          ),
        ),
        if (entry.rpcArgs != null) ...[
          const SizedBox(height: 2),
          Text(_formatData(entry.rpcArgs), style: LoggerTypography.logMeta),
        ],
      ],
    );
  }

  Widget _buildResponse() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '← ',
                style: LoggerTypography.logBody.copyWith(
                  color: LoggerColors.syntaxString,
                ),
              ),
              TextSpan(
                text: entry.rpcMethod ?? 'unknown',
                style: LoggerTypography.logBody.copyWith(
                  color: LoggerColors.fgPrimary,
                ),
              ),
            ],
          ),
        ),
        if (entry.rpcResponse != null) ...[
          const SizedBox(height: 2),
          Text(_formatData(entry.rpcResponse), style: LoggerTypography.logMeta),
        ],
      ],
    );
  }

  Widget _buildError() {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '✗ ${entry.rpcMethod ?? 'unknown'}: ',
            style: LoggerTypography.logBody.copyWith(
              color: LoggerColors.syntaxError,
            ),
          ),
          TextSpan(
            text: entry.rpcError ?? 'unknown error',
            style: LoggerTypography.logBody.copyWith(
              color: LoggerColors.severityErrorText,
            ),
          ),
        ],
      ),
    );
  }

  static String _formatData(dynamic data) {
    if (data is Map || data is List) {
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(data);
    }
    return data.toString();
  }
}
