/// Extended manifest for community-distributed plugins.
///
/// Adds author, license, repository, integrity, and version compatibility
/// fields on top of the base [PluginManifest].
library;

import 'plugin_manifest.dart';

/// Author information for a community plugin.
class PluginAuthor {
  final String name;
  final String? url;

  const PluginAuthor({required this.name, this.url});

  factory PluginAuthor.fromJson(Map<String, dynamic> json) {
    return PluginAuthor(
      name: json['name'] as String,
      url: json['url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {'name': name, if (url != null) 'url': url};
}

/// Extended manifest for community plugins.
///
/// Includes all base [PluginManifest] fields plus community-specific
/// metadata: author, license, repository, integrity hash, version
/// compatibility, and keywords.
class CommunityManifest extends PluginManifest {
  /// Plugin author information.
  final PluginAuthor? author;

  /// SPDX license identifier (e.g. "MIT", "Apache-2.0").
  final String? license;

  /// Source code repository URL.
  final String? repository;

  /// SRI-format integrity hash (e.g. "sha256-base64...").
  final String? integrity;

  /// Minimum Logger version required (semver).
  final String? minLoggerVersion;

  /// Maximum Logger version supported (semver, optional).
  final String? maxLoggerVersion;

  /// Searchable keyword tags.
  final List<String> keywords;

  const CommunityManifest({
    required super.id,
    required super.name,
    required super.version,
    super.description = '',
    required super.types,
    super.tier = PluginTier.community,
    this.author,
    this.license,
    this.repository,
    this.integrity,
    this.minLoggerVersion,
    this.maxLoggerVersion,
    this.keywords = const [],
  });

  /// Parse a community manifest from a decoded JSON map.
  ///
  /// Expects the structure defined in the `logger-plugin.json` spec.
  /// Throws [FormatException] if required fields are missing.
  factory CommunityManifest.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final version = json['version'];
    if (id is! String || name is! String || version is! String) {
      throw const FormatException(
        'Manifest requires "id", "name", and "version" as strings.',
      );
    }

    final typesRaw = json['types'];
    final types = typesRaw is List
        ? typesRaw.cast<String>().toList()
        : <String>[];

    final authorRaw = json['author'];
    final author = authorRaw is Map<String, dynamic>
        ? PluginAuthor.fromJson(authorRaw)
        : null;

    final tierRaw = json['tier'] as String?;
    // Community plugins that claim 'stdlib' are overridden to 'community'.
    final tier = tierRaw == 'stdlib'
        ? PluginTier.community
        : PluginTier.community;

    final keywordsRaw = json['keywords'];
    final keywords = keywordsRaw is List
        ? keywordsRaw.cast<String>().toList()
        : <String>[];

    return CommunityManifest(
      id: id,
      name: name,
      version: version,
      description: json['description'] as String? ?? '',
      types: types,
      tier: tier,
      author: author,
      license: json['license'] as String?,
      repository: json['repository'] as String?,
      integrity: json['integrity'] as String?,
      minLoggerVersion: json['min_logger_version'] as String?,
      maxLoggerVersion: json['max_logger_version'] as String?,
      keywords: keywords,
    );
  }

  /// Serialize to JSON for persistence.
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'version': version,
    'description': description,
    'types': types,
    'tier': 'community',
    if (author != null) 'author': author!.toJson(),
    if (license != null) 'license': license,
    if (repository != null) 'repository': repository,
    if (integrity != null) 'integrity': integrity,
    if (minLoggerVersion != null) 'min_logger_version': minLoggerVersion,
    if (maxLoggerVersion != null) 'max_logger_version': maxLoggerVersion,
    if (keywords.isNotEmpty) 'keywords': keywords,
  };

  @override
  String toString() =>
      'CommunityManifest($id v$version by ${author?.name ?? "unknown"})';
}
