import '../plugin_manifest.dart';
import '../plugin_registry.dart';
import '../plugin_types.dart';

/// Configuration for which ID patterns the uniquifier should detect.
class IdUniquifierConfig {
  final bool detectUuids;
  final bool detectObjectIds;
  final bool detectShortIds;

  const IdUniquifierConfig({
    this.detectUuids = true,
    this.detectObjectIds = true,
    this.detectShortIds = false,
  });

  IdUniquifierConfig copyWith({
    bool? detectUuids,
    bool? detectObjectIds,
    bool? detectShortIds,
  }) {
    return IdUniquifierConfig(
      detectUuids: detectUuids ?? this.detectUuids,
      detectObjectIds: detectObjectIds ?? this.detectObjectIds,
      detectShortIds: detectShortIds ?? this.detectShortIds,
    );
  }
}

/// Transform plugin that detects IDs in log text and converts them to
/// memorable adjective-animal tokens for easier visual scanning.
///
/// The mapping is deterministic: the same ID always produces the same token.
class IdUniquifierPlugin extends TransformPlugin with EnableablePlugin {
  IdUniquifierConfig config;

  IdUniquifierPlugin({this.config = const IdUniquifierConfig()});

  // ─── Pattern registry ──────────────────────────────────────────────

  static final _patterns = <String, RegExp>{
    'uuid': RegExp(
      r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}',
      caseSensitive: false,
    ),
    'objectid': RegExp(r'[0-9a-f]{24}', caseSensitive: false),
    'short_id': RegExp(r'\b[A-Za-z0-9]{8,12}\b'),
  };

  // ─── Memorable word lists ──────────────────────────────────────────

  static const _adjectives = [
    'swift',
    'calm',
    'bold',
    'warm',
    'cool',
    'keen',
    'bright',
    'dark',
    'fair',
    'kind',
    'proud',
    'wild',
    'shy',
    'glad',
    'crisp',
    'soft',
    'sharp',
    'pure',
    'rare',
    'vast',
    'pale',
    'rich',
    'deep',
    'lazy',
  ];

  static const _animals = [
    'fox',
    'owl',
    'bear',
    'wolf',
    'hawk',
    'deer',
    'lynx',
    'dove',
    'crab',
    'frog',
    'moth',
    'seal',
    'wren',
    'toad',
    'swan',
    'crow',
    'hare',
    'mole',
    'newt',
    'slug',
    'wasp',
    'orca',
    'puma',
    'ibis',
  ];

  // ─── Identity ──────────────────────────────────────────────────────

  @override
  String get id => 'dev.logger.id-uniquifier';

  @override
  String get name => 'ID Uniquifier';

  @override
  String get version => '1.0.0';

  @override
  String get description =>
      'Converts IDs to memorable adjective-animal tokens.';

  @override
  PluginManifest get manifest => const PluginManifest(
    id: 'dev.logger.id-uniquifier',
    name: 'ID Uniquifier',
    version: '1.0.0',
    description: 'Converts IDs to memorable adjective-animal tokens.',
    types: ['transform'],
  );

  @override
  String get displayName => 'ID → Token';

  // ─── Configuration ─────────────────────────────────────────────────

  // ─── Deterministic hash to token ───────────────────────────────────

  /// Converts an ID string to a deterministic adjective-animal token.
  ///
  /// Uses a simple hash to pick words. Same input always yields the same
  /// output regardless of platform (we avoid [Object.hashCode] which is
  /// not guaranteed to be stable across runs).
  String idToToken(String id) {
    // FNV-1a 32-bit for determinism across runs.
    var hash = 0x811c9dc5;
    for (var i = 0; i < id.length; i++) {
      hash ^= id.codeUnitAt(i);
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    final adj = _adjectives[hash % _adjectives.length];
    final animal = _animals[(hash ~/ _adjectives.length) % _animals.length];
    return '$adj-$animal';
  }

  // ─── Active patterns based on config ───────────────────────────────

  Map<String, RegExp> get _activePatterns {
    final active = <String, RegExp>{};
    if (config.detectUuids) active['uuid'] = _patterns['uuid']!;
    if (config.detectObjectIds) active['objectid'] = _patterns['objectid']!;
    if (config.detectShortIds) active['short_id'] = _patterns['short_id']!;
    return active;
  }

  // ─── TransformPlugin interface ─────────────────────────────────────

  @override
  bool canTransform(String input) {
    return _activePatterns.values.any((p) => p.hasMatch(input));
  }

  @override
  String transform(String input) {
    var result = input;

    // Process UUID first (longest/most specific), then objectid, then short_id.
    for (final pattern in _activePatterns.values) {
      result = result.replaceAllMapped(pattern, (match) {
        final original = match.group(0)!;
        final token = idToToken(original);
        return '$original ($token)';
      });
    }

    return result;
  }

  // ─── Lifecycle ─────────────────────────────────────────────────────

  @override
  void onRegister(PluginRegistry registry) {}

  @override
  void onDispose() {}
}
