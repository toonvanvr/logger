import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'connection_manager.dart';
import 'log_store.dart';
import 'settings_service.dart';
import 'time_range_service.dart';

@immutable
class TrayPrefs {
  final bool lokiEnabled;
  final bool grafanaEnabled;

  const TrayPrefs({required this.lokiEnabled, required this.grafanaEnabled});

  static const TrayPrefs defaults = TrayPrefs(
    lokiEnabled: false,
    grafanaEnabled: false,
  );

  Map<String, dynamic> toJson() => {
    'lokiEnabled': lokiEnabled,
    'grafanaEnabled': grafanaEnabled,
  };

  static TrayPrefs fromJson(Object? json) {
    if (json is! Map) return defaults;
    final lokiEnabled = json['lokiEnabled'];
    final grafanaEnabled = json['grafanaEnabled'];
    return TrayPrefs(
      lokiEnabled: lokiEnabled is bool ? lokiEnabled : defaults.lokiEnabled,
      grafanaEnabled: grafanaEnabled is bool
          ? grafanaEnabled
          : defaults.grafanaEnabled,
    );
  }

  TrayPrefs copyWith({bool? lokiEnabled, bool? grafanaEnabled}) {
    return TrayPrefs(
      lokiEnabled: lokiEnabled ?? this.lokiEnabled,
      grafanaEnabled: grafanaEnabled ?? this.grafanaEnabled,
    );
  }
}

abstract interface class TrayPrefsStore {
  Future<TrayPrefs> load();
  Future<void> save(TrayPrefs prefs);
}

class FileTrayPrefsStore implements TrayPrefsStore {
  final File _file;

  FileTrayPrefsStore._(this._file);

  static FileTrayPrefsStore? createDefault() {
    final dir = _defaultPrefsDir();
    if (dir == null) return null;

    final file = File('${dir.path}/tray_prefs.json');
    return FileTrayPrefsStore._(file);
  }

  @override
  Future<TrayPrefs> load() async {
    try {
      if (!await _file.exists()) return TrayPrefs.defaults;
      final raw = await _file.readAsString();
      final decoded = jsonDecode(raw);
      return TrayPrefs.fromJson(decoded);
    } catch (e) {
      debugPrint('[TrayService] prefs load failed: $e');
      return TrayPrefs.defaults;
    }
  }

  @override
  Future<void> save(TrayPrefs prefs) async {
    try {
      await _file.parent.create(recursive: true);
      await _file.writeAsString(jsonEncode(prefs.toJson()));
    } catch (e) {
      debugPrint('[TrayService] prefs save failed: $e');
    }
  }

  static Directory? _defaultPrefsDir() {
    if (Platform.isLinux) {
      final xdg = Platform.environment['XDG_CONFIG_HOME'];
      final home = Platform.environment['HOME'];
      if (xdg != null && xdg.isNotEmpty) return Directory('$xdg/logger');
      if (home != null && home.isNotEmpty)
        return Directory('$home/.config/logger');
      return null;
    }

    if (Platform.isMacOS) {
      final home = Platform.environment['HOME'];
      if (home == null || home.isEmpty) return null;
      return Directory('$home/Library/Application Support/logger');
    }

    if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'];
      if (appData != null && appData.isNotEmpty)
        return Directory('$appData\\logger');
      final home = Platform.environment['USERPROFILE'];
      if (home != null && home.isNotEmpty)
        return Directory('$home\\AppData\\Roaming\\logger');
      return null;
    }

    final home =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    if (home == null || home.isEmpty) return null;
    return Directory('$home/.config/logger');
  }
}

abstract interface class TrayPlatformApi {
  Future<void> setLabel({required String id, required String label});
  Future<void> setEnabled({required String id, required bool enabled});
  Future<void> setChecked({required String id, required bool checked});
}

class MethodChannelTrayPlatformApi implements TrayPlatformApi {
  final MethodChannel _channel;

  const MethodChannelTrayPlatformApi(this._channel);

  @override
  Future<void> setLabel({required String id, required String label}) async {
    await _channel.invokeMethod('setLabel', {'id': id, 'label': label});
  }

  @override
  Future<void> setEnabled({required String id, required bool enabled}) async {
    await _channel.invokeMethod('setEnabled', {'id': id, 'enabled': enabled});
  }

  @override
  Future<void> setChecked({required String id, required bool checked}) async {
    await _channel.invokeMethod('setChecked', {'id': id, 'checked': checked});
  }
}

abstract interface class UrlOpener {
  Future<void> openUrl(String url);
}

class CommandUrlOpener implements UrlOpener {
  final SettingsService settings;

  const CommandUrlOpener(this.settings);

  @override
  Future<void> openUrl(String url) async {
    final cmd = settings.urlOpenCommand.replaceAll('{url}', url);
    final parts = cmd.split(' ');
    if (parts.isEmpty) return;
    try {
      await Process.run(parts.first, parts.skip(1).toList());
    } catch (e) {
      debugPrint('[TrayService] openUrl failed: $e');
    }
  }
}

abstract interface class ClipboardApi {
  Future<void> copyText(String text);
}

class FlutterClipboardApi implements ClipboardApi {
  const FlutterClipboardApi();

  @override
  Future<void> copyText(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }
}

abstract interface class AdminApi {
  Future<void> setLokiEnabled({required String host, required bool enabled});
  Future<void> clearStore({required String host});
}

class HttpAdminApi implements AdminApi {
  @override
  Future<void> setLokiEnabled({
    required String host,
    required bool enabled,
  }) async {
    await _postJson(Uri.parse('http://$host:8080/api/v2/admin/loki'), {
      'enabled': enabled,
    });
  }

  @override
  Future<void> clearStore({required String host}) async {
    await _postJson(
      Uri.parse('http://$host:8080/api/v2/admin/clear_store'),
      const <String, dynamic>{},
    );
  }

  Future<void> _postJson(Uri uri, Map<String, dynamic> body) async {
    final client = HttpClient();
    try {
      final req = await client.postUrl(uri);
      req.headers.contentType = ContentType.json;
      req.add(utf8.encode(jsonEncode(body)));
      final res = await req.close();
      await res.drain();
    } catch (e) {
      debugPrint('[TrayService] Admin request failed (${uri.path}): $e');
    } finally {
      client.close(force: true);
    }
  }
}

class TrayService {
  static const String docsUrl =
      'https://github.com/toonvanvr/logger/tree/main/docs';

  static const String grafanaUrl = 'http://127.0.0.1:3000';

  static const String _idDocs = 'connection.docs';
  static const String _idHttpBase = 'connection.http_base';
  static const String _idHttpEvents = 'connection.http_events';
  static const String _idHttpData = 'connection.http_data';
  static const String _idWsViewer = 'connection.ws_viewer';
  static const String _idUdpIngest = 'connection.udp_ingest';
  static const String _idTcpIngest = 'connection.tcp_ingest';

  static const String _idExtLoki = 'extensions.loki';
  static const String _idExtGrafana = 'extensions.grafana';

  static const String _idStoreClear = 'store.clear';

  static const MethodChannel _channel = MethodChannel('com.logger/tray');

  final ConnectionManager connectionManager;
  final LogStore logStore;
  final TimeRangeService timeRangeService;
  final SettingsService settings;

  final TrayPlatformApi _platform;
  final UrlOpener _urlOpener;
  final ClipboardApi _clipboard;
  final TrayPrefsStore? _prefsStore;
  final AdminApi _adminApi;

  TrayPrefs _prefs = TrayPrefs.defaults;
  VoidCallback? _connListener;
  bool _started = false;

  TrayService({
    required this.connectionManager,
    required this.logStore,
    required this.timeRangeService,
    required this.settings,
    TrayPlatformApi? platform,
    UrlOpener? urlOpener,
    ClipboardApi? clipboard,
    TrayPrefsStore? prefsStore,
    AdminApi? adminApi,
  }) : _platform = platform ?? const MethodChannelTrayPlatformApi(_channel),
       _urlOpener = urlOpener ?? CommandUrlOpener(settings),
       _clipboard = clipboard ?? const FlutterClipboardApi(),
       _prefsStore = prefsStore ?? FileTrayPrefsStore.createDefault(),
       _adminApi = adminApi ?? HttpAdminApi();

  bool get lokiEnabled => _prefs.lokiEnabled;
  bool get grafanaEnabled => _prefs.grafanaEnabled;

  Future<void> start() async {
    if (_started) return;
    _started = true;

    _prefs = await (_prefsStore?.load() ?? Future.value(TrayPrefs.defaults));
    _enforceToggleDependency();

    _channel.setMethodCallHandler(_onMethodCall);

    _connListener = () {
      _syncConnectionMenu();
    };
    connectionManager.addListener(_connListener!);

    await _syncAllMenuState();
  }

  Future<void> dispose() async {
    if (!_started) return;
    _started = false;

    if (_connListener != null) {
      connectionManager.removeListener(_connListener!);
      _connListener = null;
    }
    _channel.setMethodCallHandler(null);
  }

  @visibleForTesting
  static Map<String, String> buildCopyTargets({required String host}) {
    final httpBase = 'http://$host:8080';
    return {
      _idHttpBase: httpBase,
      _idHttpEvents: '$httpBase/api/v2/events',
      _idHttpData: '$httpBase/api/v2/data',
      _idWsViewer: 'ws://$host:8080/api/v2/stream',
      _idUdpIngest: 'udp://$host:8081',
      _idTcpIngest: 'tcp://$host:8082',
    };
  }

  @visibleForTesting
  static Map<String, String> buildMenuLabels({required String host}) {
    final targets = buildCopyTargets(host: host);
    return {
      _idHttpBase: 'HTTP - ${targets[_idHttpBase]}',
      _idHttpEvents: 'HTTP - ${targets[_idHttpEvents]}',
      _idHttpData: 'HTTP - ${targets[_idHttpData]}',
      _idWsViewer: 'WS - ${targets[_idWsViewer]}',
      _idUdpIngest: 'UDP - ${targets[_idUdpIngest]}',
      _idTcpIngest: 'TCP - ${targets[_idTcpIngest]}',
    };
  }

  Future<void> handleAction({required String id, bool? checked}) async {
    switch (id) {
      case _idDocs:
        await _urlOpener.openUrl(docsUrl);
        return;

      case _idHttpBase ||
          _idHttpEvents ||
          _idHttpData ||
          _idWsViewer ||
          _idUdpIngest ||
          _idTcpIngest:
        await _clipboard.copyText(_copyTargetFor(id));
        return;

      case _idExtLoki:
        await _setLokiEnabled(checked ?? !_prefs.lokiEnabled);
        return;

      case _idExtGrafana:
        await _setGrafanaEnabled(checked ?? !_prefs.grafanaEnabled);
        return;

      case _idStoreClear:
        await _clearStore();
        return;

      default:
        return;
    }
  }

  Future<void> _onMethodCall(MethodCall call) async {
    if (call.method != 'onAction') return;
    final args = call.arguments;
    if (args is! Map) return;

    final id = args['id'];
    final checked = args['checked'];
    if (id is! String) return;
    await handleAction(id: id, checked: checked is bool ? checked : null);
  }

  String _copyTargetFor(String id) {
    final host = _activeHostOrDefault();
    final target = buildCopyTargets(host: host)[id];
    return target ?? '';
  }

  String _activeHostOrDefault() {
    for (final conn in connectionManager.connections.values) {
      if (!conn.isActive) continue;
      try {
        final host = Uri.parse(conn.url).host;
        if (host.isNotEmpty) return host;
      } catch (_) {
        // ignore
      }
    }
    return '127.0.0.1';
  }

  void _enforceToggleDependency() {
    if (!_prefs.lokiEnabled && _prefs.grafanaEnabled) {
      _prefs = _prefs.copyWith(grafanaEnabled: false);
    }
  }

  Future<void> _persistPrefs() async {
    await (_prefsStore?.save(_prefs) ?? Future.value());
  }

  Future<void> _setLokiEnabled(bool enabled) async {
    _prefs = _prefs.copyWith(lokiEnabled: enabled);
    if (!enabled) {
      _prefs = _prefs.copyWith(grafanaEnabled: false);
    }
    await _persistPrefs();

    final host = _activeHostOrDefault();
    if (connectionManager.isConnected) {
      await _adminApi.setLokiEnabled(host: host, enabled: enabled);
    }

    await _syncExtensionsMenu();
  }

  Future<void> _setGrafanaEnabled(bool enabled) async {
    if (enabled && !_prefs.lokiEnabled) {
      _prefs = _prefs.copyWith(lokiEnabled: true);
      await _persistPrefs();

      final host = _activeHostOrDefault();
      if (connectionManager.isConnected) {
        await _adminApi.setLokiEnabled(host: host, enabled: true);
      }
    }

    _prefs = _prefs.copyWith(grafanaEnabled: enabled);
    _enforceToggleDependency();
    await _persistPrefs();

    if (enabled) {
      await _urlOpener.openUrl(grafanaUrl);
    }

    await _syncExtensionsMenu();
  }

  Future<void> _clearStore() async {
    logStore.clear();
    timeRangeService.resetRange();

    if (!connectionManager.isConnected) return;

    final host = _activeHostOrDefault();
    await _adminApi.clearStore(host: host);
  }

  Future<void> _syncAllMenuState() async {
    await _syncConnectionMenu();
    await _syncExtensionsMenu();
  }

  Future<void> _syncConnectionMenu() async {
    final host = _activeHostOrDefault();
    final labels = buildMenuLabels(host: host);

    for (final entry in labels.entries) {
      await _platform.setLabel(id: entry.key, label: entry.value);
      await _platform.setEnabled(id: entry.key, enabled: true);
    }

    await _platform.setEnabled(id: _idDocs, enabled: true);
  }

  Future<void> _syncExtensionsMenu() async {
    await _platform.setChecked(id: _idExtLoki, checked: _prefs.lokiEnabled);

    final grafanaEnabled = _prefs.lokiEnabled;
    await _platform.setEnabled(id: _idExtGrafana, enabled: grafanaEnabled);
    await _platform.setChecked(
      id: _idExtGrafana,
      checked: grafanaEnabled && _prefs.grafanaEnabled,
    );
  }
}
