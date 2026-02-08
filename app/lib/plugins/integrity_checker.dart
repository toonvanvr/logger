/// SHA-256/384/512 integrity verification for plugin archives.
///
/// Supports both URL-fragment format (`sha256=hex...`) and
/// SRI format (`sha256-base64...`).
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Supported hash algorithms for integrity checking.
enum HashAlgorithm {
  sha256('sha256'),
  sha384('sha384'),
  sha512('sha512');

  final String id;
  const HashAlgorithm(this.id);

  /// Resolve from a string like "sha256", "sha384", "sha512".
  /// Returns null if unrecognized.
  static HashAlgorithm? fromString(String value) {
    for (final alg in values) {
      if (alg.id == value.toLowerCase()) return alg;
    }
    return null;
  }
}

/// Parsed integrity expectation from a URL fragment or SRI string.
class IntegrityExpectation {
  final HashAlgorithm algorithm;

  /// The expected digest as raw bytes.
  final Uint8List digest;

  const IntegrityExpectation({required this.algorithm, required this.digest});

  /// The expected digest as lowercase hex string.
  String get hexDigest =>
      digest.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  /// The expected digest as base64 string.
  String get base64Digest => base64Encode(digest);

  /// Format as SRI string: `sha256-base64...`
  String toSri() => '${algorithm.id}-$base64Digest';

  /// Format as URL fragment: `sha256=hex...`
  String toFragment() => '${algorithm.id}=$hexDigest';
}

/// Result of an integrity check.
enum IntegrityResult {
  /// Hash matched the expectation.
  match,

  /// Hash did not match.
  mismatch,

  /// No expectation was provided (unverified).
  noExpectation,
}

/// Verifies SHA-256/384/512 integrity of byte data.
class IntegrityChecker {
  const IntegrityChecker();

  /// Parse a URL-fragment hash string like `sha256=abcdef0123...`.
  ///
  /// Returns null if the format is invalid or the algorithm is unsupported.
  IntegrityExpectation? parseFragment(String fragment) {
    final eqIndex = fragment.indexOf('=');
    if (eqIndex < 1) return null;

    final algStr = fragment.substring(0, eqIndex);
    final algorithm = HashAlgorithm.fromString(algStr);
    if (algorithm == null) return null;

    final hexHash = fragment.substring(eqIndex + 1);
    final bytes = _hexToBytes(hexHash);
    if (bytes == null) return null;

    return IntegrityExpectation(algorithm: algorithm, digest: bytes);
  }

  /// Parse an SRI-format string like `sha256-base64...`.
  ///
  /// Returns null if the format is invalid or the algorithm is unsupported.
  IntegrityExpectation? parseSri(String sri) {
    final dashIndex = sri.indexOf('-');
    if (dashIndex < 1) return null;

    final algStr = sri.substring(0, dashIndex);
    final algorithm = HashAlgorithm.fromString(algStr);
    if (algorithm == null) return null;

    final b64 = sri.substring(dashIndex + 1);
    try {
      final bytes = base64Decode(b64);
      return IntegrityExpectation(
        algorithm: algorithm,
        digest: Uint8List.fromList(bytes),
      );
    } on FormatException {
      return null;
    }
  }

  /// Compute the hash of [data] using the given [algorithm].
  Uint8List computeHash(HashAlgorithm algorithm, Uint8List data) {
    final hash = switch (algorithm) {
      HashAlgorithm.sha256 => sha256,
      HashAlgorithm.sha384 => sha384,
      HashAlgorithm.sha512 => sha512,
    };
    final digest = hash.convert(data);
    return Uint8List.fromList(digest.bytes);
  }

  /// Verify [data] against an [expectation].
  ///
  /// Returns [IntegrityResult.match] if the computed hash matches,
  /// [IntegrityResult.mismatch] if it does not.
  IntegrityResult verify(Uint8List data, IntegrityExpectation expectation) {
    final actual = computeHash(expectation.algorithm, data);
    if (actual.length != expectation.digest.length) {
      return IntegrityResult.mismatch;
    }
    for (var i = 0; i < actual.length; i++) {
      if (actual[i] != expectation.digest[i]) {
        return IntegrityResult.mismatch;
      }
    }
    return IntegrityResult.match;
  }

  /// Parse hex string to bytes. Returns null if invalid.
  Uint8List? _hexToBytes(String hex) {
    final clean = hex.toLowerCase();
    if (clean.length.isOdd) return null;
    if (!RegExp(r'^[0-9a-f]+$').hasMatch(clean)) return null;

    final bytes = Uint8List(clean.length ~/ 2);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = int.parse(clean.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return bytes;
  }
}
