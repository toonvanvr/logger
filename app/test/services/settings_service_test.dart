import 'dart:io' show Platform;

import 'package:app/services/settings_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SettingsService', () {
    test('initial defaults', () {
      final svc = SettingsService();
      expect(svc.fileOpenCommand, 'code -g {file}:{line}');
      final expectedCmd = Platform.isMacOS ? 'open {url}' : Platform.isWindows ? 'start {url}' : 'xdg-open {url}';
      expect(svc.urlOpenCommand, expectedCmd);
      expect(svc.miniMode, isTrue);
      expect(svc.stateViewCollapsed, isFalse);
      expect(svc.shelfCollapsed, isTrue);
      expect(svc.connections, isEmpty);
    });

    test('setFileOpenCommand updates and notifies', () {
      final svc = SettingsService();
      var notified = false;
      svc.addListener(() => notified = true);

      svc.setFileOpenCommand('vim +{line} {file}');

      expect(svc.fileOpenCommand, 'vim +{line} {file}');
      expect(notified, isTrue);
    });

    test('setUrlOpenCommand updates and notifies', () {
      final svc = SettingsService();
      var notified = false;
      svc.addListener(() => notified = true);

      svc.setUrlOpenCommand('firefox {url}');

      expect(svc.urlOpenCommand, 'firefox {url}');
      expect(notified, isTrue);
    });

    test('setMiniMode toggles and notifies', () {
      final svc = SettingsService();
      var count = 0;
      svc.addListener(() => count++);

      svc.setMiniMode(false);
      expect(svc.miniMode, isFalse);

      svc.setMiniMode(true);
      expect(svc.miniMode, isTrue);
      expect(count, 2);
    });

    test('setStateViewCollapsed updates and notifies', () {
      final svc = SettingsService();
      var notified = false;
      svc.addListener(() => notified = true);

      svc.setStateViewCollapsed(true);

      expect(svc.stateViewCollapsed, isTrue);
      expect(notified, isTrue);
    });

    test('setShelfCollapsed updates and notifies', () {
      final svc = SettingsService();
      var notified = false;
      svc.addListener(() => notified = true);

      svc.setShelfCollapsed(false);

      expect(svc.shelfCollapsed, isFalse);
      expect(notified, isTrue);
    });

    test('setConnections stores list and notifies', () {
      final svc = SettingsService();
      var notified = false;
      svc.addListener(() => notified = true);

      svc.setConnections([
        {'url': 'ws://localhost:8082', 'label': 'Dev'},
      ]);

      expect(svc.connections, hasLength(1));
      expect(svc.connections.first['label'], 'Dev');
      expect(notified, isTrue);
    });

    test('connections returns unmodifiable list', () {
      final svc = SettingsService();
      svc.setConnections([
        {'url': 'ws://localhost:8082'},
      ]);

      expect(() => svc.connections.add({}), throwsUnsupportedError);
    });
  });
}
