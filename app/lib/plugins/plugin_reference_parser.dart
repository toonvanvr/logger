/// Parses user-provided plugin reference strings into [PluginReference] objects.
library;

import 'install_types.dart';
import 'integrity_checker.dart';

/// Parses plugin reference strings from various source formats.
///
/// Supports:
/// - `git+https://...[@tag][#algo=hex]`
/// - `https://...zip[#algo=hex]`
/// - `file:///path` or absolute path
class PluginReferenceParser {
  final IntegrityChecker _checker;

  const PluginReferenceParser(this._checker);

  /// Parse a user-provided plugin reference string into a [PluginReference].
  ///
  /// Returns null if the reference format is unrecognized.
  PluginReference? parseReference(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    // Git URL: git+https://...
    if (trimmed.startsWith('git+')) {
      return _parseGitReference(trimmed.substring(4));
    }

    // Local file path
    if (trimmed.startsWith('file://')) {
      final path = trimmed.substring(7);
      return PluginReference(sourceType: PluginSourceType.local, url: path);
    }
    if (trimmed.startsWith('/')) {
      return PluginReference(sourceType: PluginSourceType.local, url: trimmed);
    }

    // HTTPS URL (zip)
    if (trimmed.startsWith('https://') || trimmed.startsWith('http://')) {
      return _parseZipReference(trimmed);
    }

    return null;
  }

  /// Parse a URL with optional hash fragment.
  ///
  /// Returns `(url, integrity)` where integrity may be null.
  (String url, IntegrityExpectation? integrity) parseUrlWithHash(String input) {
    final hashIndex = input.lastIndexOf('#');
    if (hashIndex < 0) return (input, null);

    final url = input.substring(0, hashIndex);
    final fragment = input.substring(hashIndex + 1);
    final integrity = _checker.parseFragment(fragment);
    return (url, integrity);
  }

  PluginReference? _parseGitReference(String url) {
    String cleanUrl = url;
    IntegrityExpectation? integrity;
    String? tag;

    // Extract hash fragment
    final hashIndex = cleanUrl.lastIndexOf('#');
    if (hashIndex >= 0) {
      final fragment = cleanUrl.substring(hashIndex + 1);
      integrity = _checker.parseFragment(fragment);
      cleanUrl = cleanUrl.substring(0, hashIndex);
    }

    // Extract tag
    final atIndex = cleanUrl.lastIndexOf('@');
    if (atIndex > 0 && !cleanUrl.substring(atIndex).contains('/')) {
      tag = cleanUrl.substring(atIndex + 1);
      cleanUrl = cleanUrl.substring(0, atIndex);
    }

    if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
      return null;
    }

    return PluginReference(
      sourceType: PluginSourceType.git,
      url: cleanUrl,
      tag: tag,
      integrity: integrity,
    );
  }

  PluginReference? _parseZipReference(String url) {
    final (cleanUrl, integrity) = parseUrlWithHash(url);
    return PluginReference(
      sourceType: PluginSourceType.zip,
      url: cleanUrl,
      integrity: integrity,
    );
  }
}
