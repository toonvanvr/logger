import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/keybind.dart';
import '../models/server_broadcast.dart';
import '../models/viewer_message.dart';
import '../services/connection_manager.dart';
import '../services/filter_service.dart';
import '../services/keybind_registry.dart';
import '../services/log_store.dart';
import '../services/query_store.dart';
import '../services/rpc_service.dart';
import '../services/session_store.dart';
import '../services/settings_service.dart';
import '../services/uri_handler.dart';
import '../widgets/header/filter_bar.dart';
import '../widgets/header/session_selector.dart';
import '../widgets/landing/empty_landing_page.dart';
import '../widgets/log_list/log_list_view.dart';
import '../widgets/log_list/section_tabs.dart';
import '../widgets/log_list/selection_actions.dart';
import '../widgets/mini_mode/mini_title_bar.dart';
import '../widgets/settings/settings_panel.dart';
import '../widgets/state_view/state_view_section.dart';
import '../widgets/status_bar/status_bar.dart';
import '../widgets/time_travel/time_range_minimap.dart';

part 'log_viewer_connection.dart';
part 'log_viewer_content.dart';
part 'log_viewer_keyboard.dart';
part 'log_viewer_selection.dart';

/// Main screen — the full log viewer UI.
class LogViewerScreen extends StatefulWidget {
  /// URL to auto-connect to. Pass null to skip auto-connect (e.g. in tests).
  final String? serverUrl;

  /// Optional `logger://` URI to handle on startup (filter/tab/clear).
  final String? launchUri;

  const LogViewerScreen({
    super.key,
    this.serverUrl = 'ws://localhost:8080/api/v2/stream',
    this.launchUri,
  });

  @override
  State<LogViewerScreen> createState() => _LogViewerScreenState();
}

class _LogViewerScreenState extends State<LogViewerScreen>
    with _SelectionMixin, _ConnectionMixin, _KeyboardMixin, _ContentMixin {
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _registerKeybinds();
      _setupQueryStore();
      _initConnection();
      _handleLaunchUri();
    });
    _landingDelayTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _landingDelayActive = false);
    });
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _messageSub?.cancel();
    _landingDelayTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              _buildHeader(settings),
              _buildFilterBar(),
              _buildContentArea(),
              const StatusBar(),
            ],
          ),
          ..._buildSettingsOverlay(settings),
        ],
      ),
    );
  }
}
