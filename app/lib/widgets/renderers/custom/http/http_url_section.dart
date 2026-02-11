import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../theme/colors.dart';
import '../../../../theme/constants.dart';
import '../../../../theme/typography.dart';
import 'http_utils.dart';

/// Displays a URL with decoded/encoded toggle and expandable query parameters.
class HttpUrlSection extends StatefulWidget {
  final String url;

  const HttpUrlSection({super.key, required this.url});

  @override
  State<HttpUrlSection> createState() => _HttpUrlSectionState();
}

class _HttpUrlSectionState extends State<HttpUrlSection> {
  bool _showRaw = false;
  bool _paramsExpanded = true;

  @override
  Widget build(BuildContext context) {
    final parsed = parseUrl(widget.url);
    final decoded = decodeUrlForDisplay(widget.url);
    final displayUrl = _showRaw ? widget.url : decoded;
    final decodedParsed = parseUrl(displayUrl);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'URL',
          style: LoggerTypography.logMeta.copyWith(color: LoggerColors.fgMuted),
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Expanded(child: _buildUrlLine(decodedParsed)),
            const SizedBox(width: 6),
            _buildRawToggle(),
          ],
        ),
        if (parsed.queryParams.isNotEmpty) ...[
          const SizedBox(height: 6),
          _buildQueryParamsSection(parsed.queryParams),
        ],
      ],
    );
  }

  Widget _buildUrlLine(
    ({
      String? scheme,
      String? host,
      String path,
      Map<String, String> queryParams,
    })
    parsed,
  ) {
    final segments = <InlineSpan>[];

    // Scheme + host in fgMuted
    if (parsed.scheme != null) {
      segments.add(
        TextSpan(
          text: '${parsed.scheme}://',
          style: LoggerTypography.logMeta.copyWith(color: LoggerColors.fgMuted),
        ),
      );
    }
    if (parsed.host != null) {
      segments.add(
        TextSpan(
          text: parsed.host,
          style: LoggerTypography.logMeta.copyWith(color: LoggerColors.fgMuted),
        ),
      );
    }

    // Path segments — highlight those with spaces
    final pathParts = parsed.path.split('/');
    for (var i = 0; i < pathParts.length; i++) {
      if (i > 0) {
        segments.add(
          TextSpan(
            text: '/',
            style: LoggerTypography.logMeta.copyWith(
              color: LoggerColors.fgMuted,
            ),
          ),
        );
      }
      final part = pathParts[i];
      if (part.isEmpty) continue;
      final hasSpecial = part.contains(' ') || part.contains('%20');
      segments.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: Container(
            padding: hasSpecial
                ? const EdgeInsets.symmetric(horizontal: 2)
                : EdgeInsets.zero,
            decoration: hasSpecial
                ? BoxDecoration(
                    color: LoggerColors.bgHover,
                    borderRadius: kBorderRadiusSm,
                  )
                : null,
            child: Text(
              part,
              style: LoggerTypography.logMeta.copyWith(
                color: LoggerColors.fgPrimary,
              ),
            ),
          ),
        ),
      );
    }

    return Text.rich(
      TextSpan(children: segments),
      overflow: TextOverflow.ellipsis,
      maxLines: 2,
    );
  }

  Widget _buildRawToggle() {
    return GestureDetector(
      onTap: () => setState(() => _showRaw = !_showRaw),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: _showRaw ? LoggerColors.bgActive : LoggerColors.bgHover,
          borderRadius: kBorderRadiusSm,
        ),
        child: Text(
          'RAW',
          style: LoggerTypography.badge.copyWith(color: LoggerColors.fgMuted),
        ),
      ),
    );
  }

  Widget _buildQueryParamsSection(Map<String, String> params) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => setState(() => _paramsExpanded = !_paramsExpanded),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _paramsExpanded ? Icons.expand_more : Icons.chevron_right,
                size: 14,
                color: LoggerColors.fgMuted,
              ),
              const SizedBox(width: 4),
              Text(
                'Query Parameters (${params.length})',
                style: LoggerTypography.logMeta.copyWith(
                  color: LoggerColors.fgMuted,
                ),
              ),
            ],
          ),
        ),
        if (_paramsExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 18, top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: params.entries.map(_buildParamRow).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildParamRow(MapEntry<String, String> param) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            param.key,
            style: LoggerTypography.logMeta.copyWith(
              color: LoggerColors.syntaxKey,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => Clipboard.setData(ClipboardData(text: param.value)),
            child: Text(
              param.value,
              style: LoggerTypography.logMeta.copyWith(
                color: LoggerColors.fgPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
