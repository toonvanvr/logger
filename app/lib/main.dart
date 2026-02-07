import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/log_viewer.dart';
import 'services/log_connection.dart';
import 'services/log_store.dart';
import 'services/rpc_service.dart';
import 'services/session_store.dart';
import 'theme/theme.dart';

void main() {
  runApp(const LoggerApp());
}

class LoggerApp extends StatelessWidget {
  const LoggerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LogConnection()),
        ChangeNotifierProvider(create: (_) => LogStore()),
        ChangeNotifierProvider(create: (_) => SessionStore()),
        ChangeNotifierProvider(create: (_) => RpcService()),
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
