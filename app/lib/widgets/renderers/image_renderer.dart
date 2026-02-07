import 'dart:convert';

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

  static const _collapsedHeight = 200.0;

  @override
  Widget build(BuildContext context) {
    final image = widget.entry.image;

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
        // Label + dimensions.
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
        // Image content.
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: _buildImage(image),
        ),
      ],
    );
  }

  Widget _buildImage(ImageData image) {
    if (image.data != null) {
      final bytes = base64Decode(image.data!);
      final child = Image.memory(bytes, fit: BoxFit.contain);

      if (_expanded) return child;

      return ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: _collapsedHeight),
        child: child,
      );
    }

    if (image.ref != null) {
      return Text(
        'Image: ${image.ref}',
        style: LoggerTypography.logBody.copyWith(color: LoggerColors.syntaxUrl),
      );
    }

    return Text(
      '[no image data]',
      style: LoggerTypography.logBody.copyWith(color: LoggerColors.fgMuted),
    );
  }
}
