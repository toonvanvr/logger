/// Community plugin installation, verification, and management.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'community_manifest.dart';
import 'install_types.dart';
import 'integrity_checker.dart';
import 'plugin_reference_parser.dart';

export 'install_types.dart';
export 'plugin_reference_parser.dart';

/// Manages community plugin installation, verification, and storage.
class PluginInstaller {
  final IntegrityChecker _checker;
  final PluginReferenceParser _parser;
  final String _configDir;

  /// Creates a [PluginInstaller]. [configDir] overrides the storage root.
  PluginInstaller({String? configDir})
    : _checker = const IntegrityChecker(),
      _parser = const PluginReferenceParser(IntegrityChecker()),
      _configDir =
          configDir ??
          '${Platform.environment['HOME'] ?? '/tmp'}/.config/logger';

  /// Root directory for installed plugins.
  Directory get pluginDir => Directory('$_configDir/plugins');

  /// Temp directory for downloads during installation.
  Directory get cacheDir => Directory('$_configDir/plugin-cache');

  /// Delegates to [PluginReferenceParser.parseReference].
  PluginReference? parseReference(String input) =>
      _parser.parseReference(input);

  /// Delegates to [PluginReferenceParser.parseUrlWithHash].
  (String url, IntegrityExpectation? integrity) parseUrlWithHash(
    String input,
  ) => _parser.parseUrlWithHash(input);

  /// Install a plugin from a git URL (scaffolding — not yet implemented).
  Future<InstallResult> installFromGit(
    String gitUrl, {
    IntegrityExpectation? integrity,
  }) async {
    final ref = _parser.parseReference('git+$gitUrl');
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

  /// Install a plugin from a zip URL (scaffolding — not yet implemented).
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

  /// Uninstall a community plugin by ID. Returns true if it existed.
  Future<bool> uninstall(String pluginId) async {
    final dir = Directory('${pluginDir.path}/$pluginId');
    if (!dir.existsSync()) return false;
    await dir.delete(recursive: true);
    return true;
  }

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
