import 'dart:convert';

import 'package:flutter/material.dart';

import '../../models/log_entry.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';

/// Renders an RPC log entry (request, response, or error).
///
/// In v2, RPC fields are stored in [LogEntry.widget.data].
class RpcRenderer extends StatelessWidget {
  final LogEntry entry;

  const RpcRenderer({super.key, required this.entry});

  Map<String, dynamic> get _data => entry.widget?.data ?? {};

  @override
  Widget build(BuildContext context) {
    final direction = _data['direction'] as String? ?? 'request';

    return switch (direction) {
      'response' => _buildResponse(),
      'error' => _buildError(),
      _ => _buildRequest(),
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
                text: _data['method'] as String? ?? 'unknown',
                style: LoggerTypography.logBody.copyWith(
                  color: LoggerColors.fgPrimary,
                ),
              ),
            ],
          ),
        ),
        if (_data['args'] != null) ...[
          const SizedBox(height: 2),
          Text(_formatData(_data['args']), style: LoggerTypography.logMeta),
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
                text: _data['method'] as String? ?? 'unknown',
                style: LoggerTypography.logBody.copyWith(
                  color: LoggerColors.fgPrimary,
                ),
              ),
            ],
          ),
        ),
        if (_data['response'] != null) ...[
          const SizedBox(height: 2),
          Text(_formatData(_data['response']), style: LoggerTypography.logMeta),
        ],
      ],
    );
  }

  Widget _buildError() {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '✗ ${_data['method'] as String? ?? 'unknown'}: ',
            style: LoggerTypography.logBody.copyWith(
              color: LoggerColors.syntaxError,
            ),
          ),
          TextSpan(
            text: _data['error'] as String? ?? 'unknown error',
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
