import 'package:app/services/connection_manager.dart';
import 'package:app/services/log_store.dart';
import 'package:app/services/settings_service.dart';
import 'package:app/services/time_range_service.dart';
import 'package:app/services/tray_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeTrayPlatform implements TrayPlatformApi {
  final List<({String method, String id, Object value})> calls = [];

  @override
  Future<void> setChecked({required String id, required bool checked}) async {
    calls.add((method: 'setChecked', id: id, value: checked));
  }

  @override
  Future<void> setEnabled({required String id, required bool enabled}) async {
    calls.add((method: 'setEnabled', id: id, value: enabled));
  }

  @override
  Future<void> setLabel({required String id, required String label}) async {
    calls.add((method: 'setLabel', id: id, value: label));
  }

  void clear() => calls.clear();
}

class _MemoryPrefsStore implements TrayPrefsStore {
  TrayPrefs _prefs;
  TrayPrefs? lastSaved;

  _MemoryPrefsStore(this._prefs);

  @override
  Future<TrayPrefs> load() async => _prefs;

  @override
  Future<void> save(TrayPrefs prefs) async {
    _prefs = prefs;
    lastSaved = prefs;
  }
}

class _FakeUrlOpener implements UrlOpener {
  final List<String> opened = [];

  @override
  Future<void> openUrl(String url) async {
    opened.add(url);
  }
}

class _NoopClipboard implements ClipboardApi {
  @override
  Future<void> copyText(String text) async {}
}

class _NoopAdminApi implements AdminApi {
  @override
  Future<void> clearStore({required String host}) async {}

  @override
  Future<void> setLokiEnabled({required String host, required bool enabled}) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TrayService connection strings', () {
    test('buildCopyTargets uses deterministic ports and paths', () {
      final t = TrayService.buildCopyTargets(host: '127.0.0.1');
      expect(t['connection.http_base'], 'http://127.0.0.1:8080');
      expect(t['connection.http_events'], 'http://127.0.0.1:8080/api/v2/events');
      expect(t['connection.http_data'], 'http://127.0.0.1:8080/api/v2/data');
      expect(t['connection.ws_viewer'], 'ws://127.0.0.1:8080/api/v2/stream');
      expect(t['connection.udp_ingest'], 'udp://127.0.0.1:8081');
      expect(t['connection.tcp_ingest'], 'tcp://127.0.0.1:8082');
    });

    test('buildMenuLabels matches required label shape', () {
      final labels = TrayService.buildMenuLabels(host: '127.0.0.1');
      expect(labels['connection.http_base'], 'HTTP - http://127.0.0.1:8080');
      expect(
        labels['connection.http_events'],
        'HTTP - http://127.0.0.1:8080/api/v2/events',
      );
      expect(
        labels['connection.http_data'],
        'HTTP - http://127.0.0.1:8080/api/v2/data',
      );
      expect(labels['connection.ws_viewer'], 'WS - ws://127.0.0.1:8080/api/v2/stream');
      expect(labels['connection.udp_ingest'], 'UDP - udp://127.0.0.1:8081');
      expect(labels['connection.tcp_ingest'], 'TCP - tcp://127.0.0.1:8082');
    });
  });

  group('TrayService toggle dependency', () {
    test('turning Grafana ON forces Loki ON and opens Grafana', () async {
      final platform = _FakeTrayPlatform();
      final prefs = _MemoryPrefsStore(const TrayPrefs(lokiEnabled: false, grafanaEnabled: false));
      final opener = _FakeUrlOpener();

      final service = TrayService(
        connectionManager: ConnectionManager(),
        logStore: LogStore(),
        timeRangeService: TimeRangeService(),
        settings: SettingsService(),
        platform: platform,
        prefsStore: prefs,
        urlOpener: opener,
        clipboard: _NoopClipboard(),
        adminApi: _NoopAdminApi(),
      );

      await service.start();
      platform.clear();

      await service.handleAction(id: 'extensions.grafana', checked: true);

      expect(prefs.lastSaved, isNotNull);
      expect(prefs.lastSaved!.lokiEnabled, true);
      expect(prefs.lastSaved!.grafanaEnabled, true);

      expect(opener.opened, [TrayService.grafanaUrl]);

      expect(
        platform.calls,
        containsAll(<Matcher>[
          predicate((c) => c is ({String method, String id, Object value}) && c.method == 'setChecked' && c.id == 'extensions.loki' && c.value == true),
          predicate((c) => c is ({String method, String id, Object value}) && c.method == 'setEnabled' && c.id == 'extensions.grafana' && c.value == true),
          predicate((c) => c is ({String method, String id, Object value}) && c.method == 'setChecked' && c.id == 'extensions.grafana' && c.value == true),
        ]),
      );

      await service.dispose();
    });

    test('turning Loki OFF forces Grafana OFF and disables it', () async {
      final platform = _FakeTrayPlatform();
      final prefs = _MemoryPrefsStore(const TrayPrefs(lokiEnabled: true, grafanaEnabled: true));
      final opener = _FakeUrlOpener();

      final service = TrayService(
        connectionManager: ConnectionManager(),
        logStore: LogStore(),
        timeRangeService: TimeRangeService(),
        settings: SettingsService(),
        platform: platform,
        prefsStore: prefs,
        urlOpener: opener,
        clipboard: _NoopClipboard(),
        adminApi: _NoopAdminApi(),
      );

      await service.start();
      platform.clear();

      await service.handleAction(id: 'extensions.loki', checked: false);

      expect(prefs.lastSaved, isNotNull);
      expect(prefs.lastSaved!.lokiEnabled, false);
      expect(prefs.lastSaved!.grafanaEnabled, false);
      expect(opener.opened, isEmpty);

      expect(
        platform.calls,
        containsAll(<Matcher>[
          predicate((c) => c is ({String method, String id, Object value}) && c.method == 'setChecked' && c.id == 'extensions.loki' && c.value == false),
          predicate((c) => c is ({String method, String id, Object value}) && c.method == 'setEnabled' && c.id == 'extensions.grafana' && c.value == false),
          predicate((c) => c is ({String method, String id, Object value}) && c.method == 'setChecked' && c.id == 'extensions.grafana' && c.value == false),
        ]),
      );

      await service.dispose();
    });
  });
}
