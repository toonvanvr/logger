import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../models/log_entry.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';

/// Renders binary data as a hex dump.
///
/// Shows offset | hex bytes | ASCII. Toggleable between hex and UTF-8
/// views. Truncated at 1 KB by default with a "Show more" button.
class BinaryRenderer extends StatefulWidget {
  final LogEntry entry;

  const BinaryRenderer({super.key, required this.entry});

  @override
  State<BinaryRenderer> createState() => _BinaryRendererState();
}

class _BinaryRendererState extends State<BinaryRenderer> {
  bool _showUtf8 = false;
  bool _showAll = false;

  static const _truncateBytes = 1024;

  @override
  Widget build(BuildContext context) {
    final raw = widget.entry.widget?.data['data'] as String? ?? '';

    Uint8List bytes;
    try {
      bytes = base64Decode(raw);
    } catch (_) {
      bytes = Uint8List.fromList(utf8.encode(raw));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Byte count + toggle.
        Row(
          children: [
            Text(
              '${bytes.length} bytes',
              style: LoggerTypography.logMeta.copyWith(
                color: LoggerColors.fgSecondary,
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () => setState(() => _showUtf8 = !_showUtf8),
              child: Text(
                _showUtf8 ? 'View hex' : 'View UTF-8',
                style: LoggerTypography.logMeta.copyWith(
                  color: LoggerColors.syntaxUrl,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (_showUtf8)
          Text(
            utf8.decode(
              _showAll
                  ? bytes
                  : bytes.sublist(0, bytes.length.clamp(0, _truncateBytes)),
              allowMalformed: true,
            ),
            style: LoggerTypography.logBody,
          )
        else
          ..._buildHexDump(bytes),
        if (!_showAll && bytes.length > _truncateBytes) ...[
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => setState(() => _showAll = true),
            child: Text(
              'Show more',
              style: LoggerTypography.logMeta.copyWith(
                color: LoggerColors.syntaxUrl,
              ),
            ),
          ),
        ],
      ],
    );
  }

  List<Widget> _buildHexDump(Uint8List bytes) {
    final limit = _showAll
        ? bytes.length
        : bytes.length.clamp(0, _truncateBytes);
    final rows = <Widget>[];

    for (var offset = 0; offset < limit; offset += 16) {
      final end = (offset + 16).clamp(0, limit);
      final chunk = bytes.sublist(offset, end);

      final hex = chunk
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join(' ');
      final ascii = chunk
          .map((b) => (b >= 32 && b < 127) ? String.fromCharCode(b) : '.')
          .join();

      rows.add(
        Text(
          '${offset.toRadixString(16).padLeft(8, '0')}  '
          '${hex.padRight(48)}  $ascii',
          style: LoggerTypography.logBody.copyWith(
            color: LoggerColors.fgPrimary,
          ),
        ),
      );
    }

    return rows;
  }
}
