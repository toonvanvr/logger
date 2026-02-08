import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:app/plugins/community_manifest.dart';
import 'package:app/plugins/integrity_checker.dart';
import 'package:app/plugins/plugin_installer.dart';
import 'package:app/plugins/plugin_manifest.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ─── IntegrityChecker ────────────────────────────────────────────

  group('IntegrityChecker', () {
    const checker = IntegrityChecker();

    group('parseFragment', () {
      test('parses valid sha256 hex fragment', () {
        final hex =
            'e3b0c44298fc1c149afbf4c8996fb924'
            '27ae41e4649b934ca495991b7852b855';
        final result = checker.parseFragment('sha256=$hex');
        expect(result, isNotNull);
        expect(result!.algorithm, HashAlgorithm.sha256);
        expect(result.hexDigest, hex);
      });

      test('parses sha512 fragment', () {
        final hex = 'cf83e1357eefb8bd' * 8; // 128 hex chars = 64 bytes
        final result = checker.parseFragment('sha512=$hex');
        expect(result, isNotNull);
        expect(result!.algorithm, HashAlgorithm.sha512);
      });

      test('returns null for unknown algorithm', () {
        expect(checker.parseFragment('md5=abc123'), isNull);
      });

      test('returns null for empty string', () {
        expect(checker.parseFragment(''), isNull);
      });

      test('returns null for invalid hex', () {
        expect(checker.parseFragment('sha256=xyz'), isNull);
      });

      test('returns null for odd-length hex', () {
        expect(checker.parseFragment('sha256=abc'), isNull);
      });
    });

    group('parseSri', () {
      test('parses valid SRI sha256', () {
        // sha256 digest of empty bytes = known value
        final emptyHash = sha256.convert([]);
        final b64 = base64Encode(emptyHash.bytes);
        final result = checker.parseSri('sha256-$b64');
        expect(result, isNotNull);
        expect(result!.algorithm, HashAlgorithm.sha256);
        expect(result.digest.length, 32);
      });

      test('returns null for invalid base64', () {
        expect(checker.parseSri('sha256-!!!invalid!!!'), isNull);
      });

      test('returns null for missing dash', () {
        expect(checker.parseSri('sha256base64'), isNull);
      });

      test('returns null for unknown algorithm', () {
        expect(checker.parseSri('md5-dGVzdA=='), isNull);
      });
    });

    group('computeHash', () {
      test('SHA-256 of empty bytes matches known value', () {
        final result = checker.computeHash(HashAlgorithm.sha256, Uint8List(0));
        expect(result.length, 32);
        // Known SHA-256 of empty: e3b0c442...
        expect(result[0], 0xe3);
        expect(result[1], 0xb0);
      });

      test('SHA-256 of known data', () {
        final data = Uint8List.fromList(utf8.encode('hello'));
        final result = checker.computeHash(HashAlgorithm.sha256, data);
        final expected = sha256.convert(utf8.encode('hello'));
        expect(result, Uint8List.fromList(expected.bytes));
      });
    });

    group('verify', () {
      test('returns match for correct hash', () {
        final data = Uint8List.fromList(utf8.encode('test data'));
        final hash = checker.computeHash(HashAlgorithm.sha256, data);
        final expectation = IntegrityExpectation(
          algorithm: HashAlgorithm.sha256,
          digest: hash,
        );
        expect(checker.verify(data, expectation), IntegrityResult.match);
      });

      test('returns mismatch for wrong hash', () {
        final data = Uint8List.fromList(utf8.encode('test data'));
        final wrongHash = Uint8List(32); // all zeros
        final expectation = IntegrityExpectation(
          algorithm: HashAlgorithm.sha256,
          digest: wrongHash,
        );
        expect(checker.verify(data, expectation), IntegrityResult.mismatch);
      });
    });

    group('IntegrityExpectation formatting', () {
      test('toSri round-trips through parseSri', () {
        final data = Uint8List.fromList(utf8.encode('example'));
        final hash = checker.computeHash(HashAlgorithm.sha256, data);
        final expectation = IntegrityExpectation(
          algorithm: HashAlgorithm.sha256,
          digest: hash,
        );
        final sri = expectation.toSri();
        final parsed = checker.parseSri(sri);
        expect(parsed, isNotNull);
        expect(parsed!.hexDigest, expectation.hexDigest);
      });

      test('toFragment round-trips through parseFragment', () {
        final data = Uint8List.fromList(utf8.encode('example'));
        final hash = checker.computeHash(HashAlgorithm.sha256, data);
        final expectation = IntegrityExpectation(
          algorithm: HashAlgorithm.sha256,
          digest: hash,
        );
        final frag = expectation.toFragment();
        final parsed = checker.parseFragment(frag);
        expect(parsed, isNotNull);
        expect(parsed!.hexDigest, expectation.hexDigest);
      });
    });
  });

  // ─── CommunityManifest ──────────────────────────────────────────

  group('CommunityManifest', () {
    test('fromJson parses complete manifest', () {
      final json = {
        'id': 'com.example.test-plugin',
        'name': 'Test Plugin',
        'version': '1.0.0',
        'description': 'A test plugin',
        'types': ['renderer'],
        'tier': 'community',
        'author': {'name': 'Test Author', 'url': 'https://example.com'},
        'license': 'MIT',
        'repository': 'https://github.com/example/test',
        'integrity': 'sha256-47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuFU=',
        'min_logger_version': '1.0.0',
        'max_logger_version': '2.0.0',
        'keywords': ['test', 'example'],
      };

      final manifest = CommunityManifest.fromJson(json);
      expect(manifest.id, 'com.example.test-plugin');
      expect(manifest.name, 'Test Plugin');
      expect(manifest.version, '1.0.0');
      expect(manifest.description, 'A test plugin');
      expect(manifest.types, ['renderer']);
      expect(manifest.tier, PluginTier.community);
      expect(manifest.author?.name, 'Test Author');
      expect(manifest.author?.url, 'https://example.com');
      expect(manifest.license, 'MIT');
      expect(manifest.repository, 'https://github.com/example/test');
      expect(manifest.integrity, isNotNull);
      expect(manifest.minLoggerVersion, '1.0.0');
      expect(manifest.maxLoggerVersion, '2.0.0');
      expect(manifest.keywords, ['test', 'example']);
    });

    test('fromJson with minimal required fields', () {
      final json = {
        'id': 'com.example.minimal',
        'name': 'Minimal',
        'version': '0.1.0',
      };
      final manifest = CommunityManifest.fromJson(json);
      expect(manifest.id, 'com.example.minimal');
      expect(manifest.types, isEmpty);
      expect(manifest.author, isNull);
      expect(manifest.keywords, isEmpty);
    });

    test('fromJson overrides stdlib tier to community', () {
      final json = {
        'id': 'com.example.sneaky',
        'name': 'Sneaky',
        'version': '1.0.0',
        'tier': 'stdlib',
      };
      final manifest = CommunityManifest.fromJson(json);
      expect(manifest.tier, PluginTier.community);
    });

    test('fromJson throws on missing id', () {
      expect(
        () => CommunityManifest.fromJson({'name': 'X', 'version': '1.0.0'}),
        throwsFormatException,
      );
    });

    test('fromJson throws on missing name', () {
      expect(
        () => CommunityManifest.fromJson({
          'id': 'com.example.x',
          'version': '1.0.0',
        }),
        throwsFormatException,
      );
    });

    test('toJson round-trips', () {
      final manifest = CommunityManifest(
        id: 'com.example.roundtrip',
        name: 'Roundtrip',
        version: '2.0.0',
        description: 'Roundtrip test',
        types: ['filter', 'transform'],
        author: const PluginAuthor(name: 'Dev'),
        license: 'Apache-2.0',
        keywords: ['round', 'trip'],
      );
      final json = manifest.toJson();
      final restored = CommunityManifest.fromJson(json);
      expect(restored.id, manifest.id);
      expect(restored.name, manifest.name);
      expect(restored.version, manifest.version);
      expect(restored.types, manifest.types);
      expect(restored.license, manifest.license);
      expect(restored.keywords, manifest.keywords);
    });
  });

  // ─── PluginInstaller — Reference Parsing ────────────────────────

  group('PluginInstaller', () {
    late PluginInstaller installer;
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('logger_test_');
      installer = PluginInstaller(configDir: tempDir.path);
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    group('parseReference', () {
      test('parses git+https URL', () {
        const url = 'git+https://github.com/user/plugin.git';
        final ref = installer.parseReference(url);
        expect(ref, isNotNull);
        expect(ref!.sourceType, PluginSourceType.git);
        expect(ref.url, 'https://github.com/user/plugin.git');
        expect(ref.tag, isNull);
        expect(ref.integrity, isNull);
      });

      test('parses git URL with tag', () {
        const url = 'git+https://github.com/user/plugin.git@v1.0.0';
        final ref = installer.parseReference(url);
        expect(ref, isNotNull);
        expect(ref!.tag, 'v1.0.0');
        expect(ref.url, 'https://github.com/user/plugin.git');
      });

      test('parses git URL with tag and hash', () {
        final hex =
            'e3b0c44298fc1c149afbf4c8996fb924'
            '27ae41e4649b934ca495991b7852b855';
        final url = 'git+https://github.com/user/plugin.git@v1.0.0#sha256=$hex';
        final ref = installer.parseReference(url);
        expect(ref, isNotNull);
        expect(ref!.tag, 'v1.0.0');
        expect(ref.integrity, isNotNull);
        expect(ref.integrity!.algorithm, HashAlgorithm.sha256);
      });

      test('parses https zip URL', () {
        const url = 'https://example.com/plugin.zip';
        final ref = installer.parseReference(url);
        expect(ref, isNotNull);
        expect(ref!.sourceType, PluginSourceType.zip);
        expect(ref.url, 'https://example.com/plugin.zip');
      });

      test('parses https zip URL with hash', () {
        final hex =
            'e3b0c44298fc1c149afbf4c8996fb924'
            '27ae41e4649b934ca495991b7852b855';
        final url = 'https://example.com/plugin.zip#sha256=$hex';
        final ref = installer.parseReference(url);
        expect(ref, isNotNull);
        expect(ref!.sourceType, PluginSourceType.zip);
        expect(ref.integrity, isNotNull);
      });

      test('parses file:// URL', () {
        const url = 'file:///home/user/plugins/my-plugin';
        final ref = installer.parseReference(url);
        expect(ref, isNotNull);
        expect(ref!.sourceType, PluginSourceType.local);
        expect(ref.url, '/home/user/plugins/my-plugin');
      });

      test('parses absolute path', () {
        const url = '/home/user/plugins/my-plugin';
        final ref = installer.parseReference(url);
        expect(ref, isNotNull);
        expect(ref!.sourceType, PluginSourceType.local);
        expect(ref.url, '/home/user/plugins/my-plugin');
      });

      test('returns null for empty string', () {
        expect(installer.parseReference(''), isNull);
      });

      test('returns null for unrecognized format', () {
        expect(installer.parseReference('ftp://bad.example.com'), isNull);
      });
    });

    group('parseUrlWithHash', () {
      test('extracts hash from URL', () {
        final hex =
            'e3b0c44298fc1c149afbf4c8996fb924'
            '27ae41e4649b934ca495991b7852b855';
        final (url, integrity) = installer.parseUrlWithHash(
          'https://example.com/plugin.zip#sha256=$hex',
        );
        expect(url, 'https://example.com/plugin.zip');
        expect(integrity, isNotNull);
        expect(integrity!.algorithm, HashAlgorithm.sha256);
      });

      test('returns null integrity for URL without hash', () {
        final (url, integrity) = installer.parseUrlWithHash(
          'https://example.com/plugin.zip',
        );
        expect(url, 'https://example.com/plugin.zip');
        expect(integrity, isNull);
      });
    });

    group('installFromLocal', () {
      test('fails for nonexistent path', () async {
        final result = await installer.installFromLocal(
          '${tempDir.path}/nonexistent',
        );
        expect(result, isA<InstallFailure>());
        final failure = result as InstallFailure;
        expect(failure.error, InstallError.diskError);
      });

      test('fails when manifest not found', () async {
        final pluginPath = '${tempDir.path}/empty-plugin';
        Directory(pluginPath).createSync();

        final result = await installer.installFromLocal(pluginPath);
        expect(result, isA<InstallFailure>());
        final failure = result as InstallFailure;
        expect(failure.error, InstallError.manifestNotFound);
      });

      test('fails on invalid manifest JSON', () async {
        final pluginPath = '${tempDir.path}/bad-json-plugin';
        Directory(pluginPath).createSync();
        File(
          '$pluginPath/logger-plugin.json',
        ).writeAsStringSync('not valid json');

        final result = await installer.installFromLocal(pluginPath);
        expect(result, isA<InstallFailure>());
        final failure = result as InstallFailure;
        expect(failure.error, InstallError.manifestInvalid);
      });

      test('succeeds with valid local plugin', () async {
        final pluginPath = '${tempDir.path}/valid-plugin';
        Directory(pluginPath).createSync();
        File('$pluginPath/logger-plugin.json').writeAsStringSync(
          jsonEncode({
            'id': 'com.example.valid-plugin',
            'name': 'Valid Plugin',
            'version': '1.0.0',
            'types': ['filter'],
            'tier': 'community',
          }),
        );

        final result = await installer.installFromLocal(pluginPath);
        expect(result, isA<InstallSuccess>());
        final success = result as InstallSuccess;
        expect(success.manifest.id, 'com.example.valid-plugin');
        expect(success.manifest.name, 'Valid Plugin');
      });

      test('rejects invalid plugin ID', () async {
        final pluginPath = '${tempDir.path}/bad-id-plugin';
        Directory(pluginPath).createSync();
        File('$pluginPath/logger-plugin.json').writeAsStringSync(
          jsonEncode({'id': 'INVALID ID!', 'name': 'Bad', 'version': '1.0.0'}),
        );

        final result = await installer.installFromLocal(pluginPath);
        expect(result, isA<InstallFailure>());
        final failure = result as InstallFailure;
        expect(failure.error, InstallError.manifestInvalid);
      });
    });

    group('listInstalled', () {
      test('returns empty when no plugins', () async {
        final installed = await installer.listInstalled();
        expect(installed, isEmpty);
      });

      test('lists installed plugins', () async {
        // Install a plugin first
        final pluginDir = Directory('${tempDir.path}/plugins/com.example.test');
        pluginDir.createSync(recursive: true);
        File('${pluginDir.path}/logger-plugin.json').writeAsStringSync(
          jsonEncode({
            'id': 'com.example.test',
            'name': 'Test',
            'version': '1.0.0',
            'types': ['filter'],
          }),
        );

        final installed = await installer.listInstalled();
        expect(installed.length, 1);
        expect(installed.first.id, 'com.example.test');
      });
    });

    group('uninstall', () {
      test('removes installed plugin', () async {
        final pluginDir = Directory(
          '${tempDir.path}/plugins/com.example.remove',
        );
        pluginDir.createSync(recursive: true);
        File('${pluginDir.path}/logger-plugin.json').writeAsStringSync('{}');

        final removed = await installer.uninstall('com.example.remove');
        expect(removed, isTrue);
        expect(pluginDir.existsSync(), isFalse);
      });

      test('returns false for nonexistent plugin', () async {
        final removed = await installer.uninstall('com.example.nonexistent');
        expect(removed, isFalse);
      });
    });
  });
}
