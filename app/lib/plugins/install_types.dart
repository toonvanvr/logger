/// Type definitions for plugin installation results and references.
library;

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
