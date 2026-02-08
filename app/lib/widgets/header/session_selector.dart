import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/server_message.dart';
import '../../services/session_store.dart';
import '../../services/settings_service.dart';
import '../../theme/colors.dart';
import 'overflow_menu.dart';
import 'session_button.dart';
import 'window_controls.dart';

const _headerHeight = 40.0;
const _buttonMinWidth = 48.0;

/// Compact header bar with session buttons and controls.
class SessionSelector extends StatefulWidget {
  /// Whether the filter bar below is expanded.
  final bool isFilterExpanded;

  /// Called when the filter toggle button is pressed.
  final VoidCallback? onFilterToggle;

  /// Called when the RPC panel toggle button is pressed.
  final VoidCallback? onRpcToggle;

  const SessionSelector({
    super.key,
    this.isFilterExpanded = false,
    this.onFilterToggle,
    this.onRpcToggle,
  });

  @override
  State<SessionSelector> createState() => _SessionSelectorState();
}

class _SessionSelectorState extends State<SessionSelector> {
  final ScrollController _scrollController = ScrollController();
  int? _lastClickedIndex;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _rangeSelect(int index, List<SessionInfo> sessions, SessionStore store) {
    final anchor = _lastClickedIndex ?? index;
    final start = anchor < index ? anchor : index;
    final end = anchor < index ? index : anchor;
    store.deselectAll();
    for (var i = start; i <= end; i++) {
      store.toggleSession(sessions[i].sessionId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionStore = context.watch<SessionStore>();
    final sessions = sessionStore.sessions;

    return Container(
      height: _headerHeight,
      decoration: const BoxDecoration(
        color: LoggerColors.bgRaised,
        border: Border(
          bottom: BorderSide(color: LoggerColors.borderSubtle, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Session buttons with horizontal scroll
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxVisible = (constraints.maxWidth / _buttonMinWidth)
                    .floor()
                    .clamp(4, 20);
                final visible = sessions.length > maxVisible
                    ? sessions.sublist(0, maxVisible)
                    : sessions;
                final hasOverflow = sessions.length > maxVisible;

                return Row(
                  children: [
                    Expanded(
                      child: Listener(
                        onPointerSignal: (event) {
                          if (event is PointerScrollEvent &&
                              _scrollController.hasClients) {
                            final offset =
                                (_scrollController.offset +
                                        event.scrollDelta.dy)
                                    .clamp(
                                      0.0,
                                      _scrollController
                                          .position
                                          .maxScrollExtent,
                                    );
                            _scrollController.jumpTo(offset);
                          }
                        },
                        child: ListView(
                          controller: _scrollController,
                          scrollDirection: Axis.horizontal,
                          children: [
                            for (var i = 0; i < visible.length; i++)
                              SessionButton(
                                session: visible[i],
                                isSelected: sessionStore.isSelected(
                                  visible[i].sessionId,
                                ),
                                onTap: () {
                                  setState(() => _lastClickedIndex = i);
                                  sessionStore.selectOnly(visible[i].sessionId);
                                },
                                onCtrlTap: () {
                                  setState(() => _lastClickedIndex = i);
                                  sessionStore.toggleSession(
                                    visible[i].sessionId,
                                  );
                                },
                                onShiftTap: () =>
                                    _rangeSelect(i, sessions, sessionStore),
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (hasOverflow) OverflowButton(overflowSessions: sessions),
                  ],
                );
              },
            ),
          ),
          // Filter toggle
          HeaderIconButton(
            icon: Icons.filter_list,
            tooltip: 'Toggle filters',
            isActive: widget.isFilterExpanded,
            onTap: widget.onFilterToggle,
          ),
          // Settings panel toggle
          HeaderIconButton(
            icon: Icons.settings,
            tooltip: 'Toggle settings panel',
            isActive: false,
            onTap: widget.onRpcToggle,
          ),
          // Mini mode toggle
          HeaderIconButton(
            icon: Icons.view_compact_outlined,
            tooltip: 'Mini mode (Ctrl+M)',
            isActive: false,
            onTap: () => context.read<SettingsService>().setMiniMode(true),
          ),
          const SizedBox(width: 4),
          // Always-on-top toggle
          const AlwaysOnTopButton(),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}
