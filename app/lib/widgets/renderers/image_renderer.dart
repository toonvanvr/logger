import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../models/log_entry.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';

/// Renders an image log entry.
///
/// Base64 data is decoded via [Image.memory]; URL references are shown
/// as a placeholder until server fetch is implemented. Constrained to
/// 200 px max height initially; tap to expand full size.
class ImageRenderer extends StatefulWidget {
  final LogEntry entry;

  const ImageRenderer({super.key, required this.entry});

  @override
  State<ImageRenderer> createState() => _ImageRendererState();
}

class _ImageRendererState extends State<ImageRenderer> {
  bool _expanded = false;
  Uint8List? _cachedBytes;
  String? _cachedDataKey;

  static const _collapsedHeight = 200.0;

  Uint8List _getDecodedBytes(String data) {
    if (data != _cachedDataKey || _cachedBytes == null) {
      _cachedBytes = base64Decode(data);
      _cachedDataKey = data;
    }
    return _cachedBytes!;
  }

  @override
  Widget build(BuildContext context) {
    final image = widget.entry.widget != null
        ? ImageData.fromJson(widget.entry.widget!.data)
        : null;

    if (image == null) {
      return Text(
        '[no image data]',
        style: LoggerTypography.logBody.copyWith(color: LoggerColors.fgMuted),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (image.label != null || image.width != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              [
                if (image.label != null) image.label,
                if (image.width != null && image.height != null)
                  '${image.width}×${image.height}',
              ].join('  '),
              style: LoggerTypography.logMeta.copyWith(
                color: LoggerColors.fgSecondary,
              ),
            ),
          ),
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: _buildImage(image),
        ),
      ],
    );
  }

  Widget _buildImage(ImageData image) {
    if (image.data != null) {
      final bytes = _getDecodedBytes(image.data!);

      // Images below threshold are likely tracking pixels or spacers
      if (bytes.length < 200 && (image.width == null || image.width! <= 4)) {
        return Container(
          height: 48,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: LoggerColors.bgOverlay,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: LoggerColors.borderSubtle),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.image, size: 24, color: LoggerColors.fgMuted),
              const SizedBox(width: 8),
              Text(
                'Image (${image.mimeType ?? 'unknown'}${image.width != null ? ' ${image.width}×${image.height}' : ''}, ${bytes.length} bytes)',
                style: LoggerTypography.logMeta.copyWith(
                  color: LoggerColors.fgSecondary,
                ),
              ),
            ],
          ),
        );
      }

      final child = Image.memory(
        bytes,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded || frame != null) return child;
          return const SizedBox(height: 48, width: 48);
        },
      );

      if (_expanded) return child;

      return ConstrainedBox(
        constraints: const BoxConstraints(
          maxHeight: _collapsedHeight,
          minHeight: 48,
          minWidth: 48,
        ),
        child: child,
      );
    }

    if (image.ref != null) {
      return Container(
        height: 48,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: LoggerColors.bgOverlay,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: LoggerColors.borderSubtle),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.image_outlined,
              size: 24,
              color: LoggerColors.fgMuted,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                image.ref!,
                style: LoggerTypography.logBody.copyWith(
                  color: LoggerColors.syntaxUrl,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    return Text(
      '[no image data]',
      style: LoggerTypography.logBody.copyWith(color: LoggerColors.fgMuted),
    );
  }
}
