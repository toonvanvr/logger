/// Scaffolding for community plugin installation, verification, and management.
///
/// Handles download from git/zip/local sources, integrity verification,
/// manifest validation, and storage in `~/.config/logger/plugins/`.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'community_manifest.dart';
import 'integrity_checker.dart';

/// Result of a plugin installation attempt.
sealed class InstallResult {
  const InstallResult();
}

/// Successful installation with the parsed manifest.
class InstallSuccess extends InstallResult {
  final CommunityManifest manifest;
  const InstallSuccess(this.manifest);
}

/// Installation failed with an error.
class InstallFailure extends InstallResult {
  final InstallError error;
  final String detail;
  const InstallFailure(this.error, this.detail);

  @override
  String toString() => 'InstallFailure($error: $detail)';
}

/// Categorized installation errors.
enum InstallError {
  manifestNotFound,
  manifestInvalid,
  hashMismatch,
  versionIncompatible,
  idConflict,
  networkError,
  diskError,
  invalidReference,
}

/// The type of plugin source reference.
enum PluginSourceType { git, zip, local }

/// A parsed plugin reference with optional integrity hash.
class PluginReference {
  final PluginSourceType sourceType;
  final String url;
  final String? tag;
  final IntegrityExpectation? integrity;

  const PluginReference({
    required this.sourceType,
    required this.url,
    this.tag,
    this.integrity,
  });
}

/// Manages community plugin installation, verification, and storage.
///
/// This is the scaffolding — methods define the interface and perform
/// validation/parsing. Actual network I/O (git clone, HTTP download)
/// is deferred to a future implementation.
class PluginInstaller {
  final IntegrityChecker _checker;
  final String _configDir;

  /// Creates a [PluginInstaller].
  ///
  /// [configDir] overrides the plugin storage root (default:
  /// `~/.config/logger`). Useful for testing.
  PluginInstaller({String? configDir})
    : _checker = const IntegrityChecker(),
      _configDir =
          configDir ??
          '${Platform.environment['HOME'] ?? '/tmp'}/.config/logger';

  /// Root directory for installed plugins.
  Directory get pluginDir => Directory('$_configDir/plugins');

  /// Temp directory for downloads during installation.
  Directory get cacheDir => Directory('$_configDir/plugin-cache');

  // ─── Reference Parsing ─────────────────────────────────────────

  /// Parse a user-provided plugin reference string into a [PluginReference].
  ///
  /// Supports:
  /// - `git+https://...[@tag][#algo=hex]`
  /// - `https://...zip[#algo=hex]`
  /// - `file:///path` or absolute path
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

  // ─── Installation ──────────────────────────────────────────────

  /// Install a plugin from a git URL.
  ///
  /// Scaffolding: validates the reference format and returns.
  /// Actual git clone is deferred to future implementation.
  Future<InstallResult> installFromGit(
    String gitUrl, {
    IntegrityExpectation? integrity,
  }) async {
    final ref = _parseGitReference(gitUrl);
    if (ref == null) {
      return const InstallFailure(
        InstallError.invalidReference,
        'Invalid git URL format.',
      );
    }
    // TODO: Implement git clone → temp dir → validate manifest → install
    return const InstallFailure(
      InstallError.networkError,
      'Git installation not yet implemented.',
    );
  }

  /// Install a plugin from a zip URL.
  ///
  /// Scaffolding: validates the reference and returns.
  /// Actual HTTP download is deferred to future implementation.
  Future<InstallResult> installFromZip(
    String zipUrl, {
    IntegrityExpectation? integrity,
  }) async {
    if (!zipUrl.startsWith('http://') && !zipUrl.startsWith('https://')) {
      return const InstallFailure(
        InstallError.invalidReference,
        'Zip URL must start with http:// or https://.',
      );
    }
    // TODO: Implement HTTP GET → verify hash → extract → validate → install
    return const InstallFailure(
      InstallError.networkError,
      'Zip installation not yet implemented.',
    );
  }

  /// Install a plugin from a local filesystem path.
  ///
  /// Validates that the path exists and contains a valid manifest.
  Future<InstallResult> installFromLocal(String path) async {
    final dir = Directory(path);
    if (!dir.existsSync()) {
      return InstallFailure(
        InstallError.diskError,
        'Directory does not exist: $path',
      );
    }

    final manifestFile = File('$path/logger-plugin.json');
    if (!manifestFile.existsSync()) {
      return const InstallFailure(
        InstallError.manifestNotFound,
        'No logger-plugin.json found in plugin directory.',
      );
    }

    try {
      final manifest = await _readManifest(manifestFile);
      return _installManifest(manifest, dir);
    } on FormatException catch (e) {
      return InstallFailure(InstallError.manifestInvalid, e.message);
    }
  }

  // ─── Query ─────────────────────────────────────────────────────

  /// List all installed community plugins.
  Future<List<CommunityManifest>> listInstalled() async {
    if (!pluginDir.existsSync()) return [];

    final manifests = <CommunityManifest>[];
    await for (final entity in pluginDir.list()) {
      if (entity is! Directory) continue;
      final manifestFile = File('${entity.path}/logger-plugin.json');
      if (!manifestFile.existsSync()) continue;
      try {
        final manifest = await _readManifest(manifestFile);
        manifests.add(manifest);
      } on FormatException {
        // Skip plugins with invalid manifests.
      }
    }
    return manifests;
  }

  /// Uninstall a community plugin by ID.
  ///
  /// Removes the plugin directory and returns true if it existed.
  Future<bool> uninstall(String pluginId) async {
    final dir = Directory('${pluginDir.path}/$pluginId');
    if (!dir.existsSync()) return false;
    await dir.delete(recursive: true);
    return true;
  }

  // ─── Integrity ─────────────────────────────────────────────────

  /// Verify a file's integrity against an expected hash.
  IntegrityResult verifyBytes(
    List<int> bytes,
    IntegrityExpectation expectation,
  ) {
    return _checker.verify(
      bytes is Uint8List ? bytes : Uint8List.fromList(bytes),
      expectation,
    );
  }

  // ─── Private Helpers ───────────────────────────────────────────

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

  Future<CommunityManifest> _readManifest(File file) async {
    final content = await file.readAsString();
    final Map<String, dynamic> json;
    try {
      json = (await _parseJson(content)) as Map<String, dynamic>;
    } catch (_) {
      throw const FormatException('Invalid JSON in logger-plugin.json.');
    }
    return CommunityManifest.fromJson(json);
  }

  Future<dynamic> _parseJson(String content) async {
    // Using dart:convert for JSON parsing.
    return const JsonDecoder().convert(content);
  }

  InstallResult _installManifest(CommunityManifest manifest, Directory source) {
    // Validate plugin ID format
    if (!RegExp(r'^[a-z][a-z0-9.\-]*$').hasMatch(manifest.id)) {
      return InstallFailure(
        InstallError.manifestInvalid,
        'Invalid plugin ID: must match [a-z][a-z0-9.-]*. Got: "${manifest.id}"',
      );
    }

    // Check for ID conflict
    final targetDir = Directory('${pluginDir.path}/${manifest.id}');
    if (targetDir.existsSync()) {
      return InstallFailure(
        InstallError.idConflict,
        'Plugin "${manifest.id}" is already installed.',
      );
    }

    // Copy to plugin directory
    try {
      _copyDirectory(source, targetDir);
    } catch (e) {
      return InstallFailure(
        InstallError.diskError,
        'Failed to copy plugin: $e',
      );
    }

    return InstallSuccess(manifest);
  }

  void _copyDirectory(Directory source, Directory target) {
    target.createSync(recursive: true);
    for (final entity in source.listSync(recursive: false)) {
      final targetPath = '${target.path}/${entity.uri.pathSegments.last}';
      if (entity is File) {
        entity.copySync(targetPath);
      } else if (entity is Directory) {
        _copyDirectory(entity, Directory(targetPath));
      }
    }
  }
}
