import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'plugins/builtin/chart_plugin.dart';
import 'plugins/builtin/id_uniquifier_plugin.dart';
import 'plugins/builtin/kv_plugin.dart';
import 'plugins/builtin/log_type_filter_plugin.dart';
import 'plugins/builtin/progress_plugin.dart';
import 'plugins/builtin/smart_search_plugin.dart';
import 'plugins/builtin/table_plugin.dart';
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
import 'theme/theme.dart';

void main() {
  // Register built-in plugins
  PluginRegistry.instance.register(ProgressRendererPlugin());
  PluginRegistry.instance.register(TableRendererPlugin());
  PluginRegistry.instance.register(KvRendererPlugin());
  PluginRegistry.instance.register(IdUniquifierPlugin());
  PluginRegistry.instance.register(LogTypeFilterPlugin());
  PluginRegistry.instance.register(SmartSearchPlugin());
  PluginRegistry.instance.register(ChartRendererPlugin());

  runApp(const LoggerApp());
}

class LoggerApp extends StatelessWidget {
  const LoggerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ConnectionManager()),
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
        home: const LogViewerScreen(),
      ),
    );
  }
}
