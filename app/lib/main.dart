import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'plugins/builtin/chart_plugin.dart';
import 'plugins/builtin/docker_logs_plugin.dart';
import 'plugins/builtin/http_filter_plugin.dart';
import 'plugins/builtin/http_request_plugin.dart';
import 'plugins/builtin/id_uniquifier_plugin.dart';
import 'plugins/builtin/kv_plugin.dart';
import 'plugins/builtin/log_type_filter_plugin.dart';
import 'plugins/builtin/progress_plugin.dart';
import 'plugins/builtin/smart_search_plugin.dart';
import 'plugins/builtin/table_plugin.dart';
import 'plugins/builtin/theme_plugin.dart';
import 'plugins/plugin_registry.dart';
import 'screens/log_viewer.dart';
import 'services/connection_manager.dart';
import 'services/log_store.dart';
import 'services/query_store.dart';
import 'services/rpc_service.dart';
import 'services/session_store.dart';
import 'services/settings_service.dart';
import 'services/sticky_state.dart';
import 'services/time_range_service.dart';
import 'services/uri_handler.dart';
import 'services/window_service.dart';
import 'theme/theme.dart';

// HOW TO ADD A PLUGIN:
// 1. Create plugin class in plugins/builtin/ (extend LoggerPlugin, mix in EnableablePlugin if needed)
// 2. Import above
// 3. Register instance in main() below with PluginRegistry.instance.register()

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Default to mini mode — hide window decoration at startup
  WindowService.setDecorated(false);

  // Register built-in plugins
  PluginRegistry.instance.register(ProgressRendererPlugin());
  PluginRegistry.instance.register(TableRendererPlugin());
  PluginRegistry.instance.register(KvRendererPlugin());
  PluginRegistry.instance.register(IdUniquifierPlugin());
  PluginRegistry.instance.register(LogTypeFilterPlugin());
  PluginRegistry.instance.register(SmartSearchPlugin());
  PluginRegistry.instance.register(ChartRendererPlugin());
  PluginRegistry.instance.register(DockerLogsPlugin());
  PluginRegistry.instance.register(HttpRequestRendererPlugin());
  PluginRegistry.instance.register(HttpFilterPlugin());
  PluginRegistry.instance.register(ThemePlugin());

  runApp(const LoggerApp());
}

class LoggerApp extends StatefulWidget {
  const LoggerApp({super.key});

  @override
  State<LoggerApp> createState() => _LoggerAppState();
}

class _LoggerAppState extends State<LoggerApp> {
  static const _uriChannel = MethodChannel('com.logger/uri');

  final _connectionManager = ConnectionManager();
  String? _launchUri;

  @override
  void initState() {
    super.initState();
    _launchUri = UriHandler.extractFromArgs(Platform.executableArguments);
    _handleLaunchConnect();
    _uriChannel.setMethodCallHandler(_onUriMethodCall);
  }

  /// Process `logger://connect` URIs immediately (before widget tree exists).
  void _handleLaunchConnect() {
    if (_launchUri == null) return;
    final parsed = Uri.tryParse(_launchUri!);
    if (parsed != null &&
        parsed.scheme == 'logger' &&
        parsed.host == 'connect') {
      UriHandler.handleUri(
        _launchUri!,
        connectionManager: _connectionManager,
        onFilter: (_) {},
        onTab: (_) {},
        onClear: () {},
      );
    }
  }

  /// Handle URI forwarded from native side via method channel.
  Future<void> _onUriMethodCall(MethodCall call) async {
    if (call.method == 'handleUri' && call.arguments is String) {
      UriHandler.handleUri(
        call.arguments as String,
        connectionManager: _connectionManager,
        onFilter: (_) {},
        onTab: (_) {},
        onClear: () {},
      );
    }
  }

  @override
  void dispose() {
    _uriChannel.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _connectionManager),
        ChangeNotifierProvider(create: (_) => LogStore()),
        ChangeNotifierProvider(create: (_) => SessionStore()),
        ChangeNotifierProvider(create: (_) => RpcService()),
        ChangeNotifierProvider(create: (_) => QueryStore()),
        ChangeNotifierProvider(create: (_) => StickyStateService()),
        ChangeNotifierProvider(create: (_) => SettingsService()),
        ChangeNotifierProvider(create: (_) => TimeRangeService()),
      ],
      child: MaterialApp(
        title: 'Logger',
        debugShowCheckedModeBanner: false,
        theme: createLoggerTheme(),
        home: LogViewerScreen(launchUri: _launchUri),
      ),
    );
  }
}
