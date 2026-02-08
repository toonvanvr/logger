/// Metadata describing a plugin's identity and capabilities.
library;

/// Distribution tier for a plugin.
enum PluginTier { stdlib, community }

/// Immutable manifest describing a plugin.
class PluginManifest {
  final String id;
  final String name;
  final String version;
  final String description;
  final List<String> types;
  final PluginTier tier;

  const PluginManifest({
    required this.id,
    required this.name,
    required this.version,
    this.description = '',
    required this.types,
    this.tier = PluginTier.stdlib,
  });

  @override
  String toString() => 'PluginManifest($id v$version)';
}
