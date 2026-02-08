import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/server_message.dart';
import '../../services/log_connection.dart';
import '../../services/session_store.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';
import 'overflow_menu.dart';
import 'window_controls.dart';

const _headerHeight = 40.0;
const _sessionDotSize = 6.0;
const _buttonHPadding = 8.0;
const _buttonMaxWidth = 120.0;
const _buttonMinWidth = 48.0;

/// Compact header bar with session buttons and controls.
class SessionSelector extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final sessionStore = context.watch<SessionStore>();
    final connection = context.watch<LogConnection>();
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
          // App title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              'Logger',
              style: LoggerTypography.headerBtn.copyWith(
                color: LoggerColors.fgSecondary,
              ),
            ),
          ),
          Container(
            width: 1,
            height: _headerHeight,
            color: LoggerColors.borderSubtle,
          ),
          // Session buttons (dynamic count based on available width)
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
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          for (final session in visible)
                            SessionButton(
                              session: session,
                              isSelected: sessionStore.isSelected(
                                session.sessionId,
                              ),
                              onTap: () =>
                                  sessionStore.selectOnly(session.sessionId),
                              onCtrlTap: () =>
                                  sessionStore.toggleSession(session.sessionId),
                            ),
                        ],
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
            isActive: isFilterExpanded,
            onTap: onFilterToggle,
          ),
          // Settings panel toggle
          HeaderIconButton(
            icon: Icons.settings,
            tooltip: 'Toggle settings panel',
            isActive: false,
            onTap: onRpcToggle,
          ),
          const SizedBox(width: 4),
          // Connection indicator
          ConnectionIndicator(isConnected: connection.isConnected),
          const SizedBox(width: 8),
          // Always-on-top toggle
          const AlwaysOnTopButton(),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

/// A single session button in the header.
class SessionButton extends StatefulWidget {
  final SessionInfo session;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onCtrlTap;

  const SessionButton({
    super.key,
    required this.session,
    required this.isSelected,
    required this.onTap,
    required this.onCtrlTap,
  });

  @override
  State<SessionButton> createState() => _SessionButtonState();
}

class _SessionButtonState extends State<SessionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final poolColor =
        LoggerColors.sessionPool[widget.session.colorIndex %
            LoggerColors.sessionPool.length];

    Color bg;
    if (widget.isSelected) {
      bg = LoggerColors.bgActive;
    } else if (_hovered) {
      bg = LoggerColors.bgHover;
    } else {
      bg = Colors.transparent;
    }

    final textColor = widget.isSelected
        ? LoggerColors.fgPrimary
        : LoggerColors.fgSecondary;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () {
          if (HardwareKeyboard.instance.logicalKeysPressed.contains(
                LogicalKeyboardKey.controlLeft,
              ) ||
              HardwareKeyboard.instance.logicalKeysPressed.contains(
                LogicalKeyboardKey.controlRight,
              )) {
            widget.onCtrlTap();
          } else {
            widget.onTap();
          }
        },
        child: Container(
          constraints: const BoxConstraints(
            minWidth: _buttonMinWidth,
            maxWidth: _buttonMaxWidth,
          ),
          height: _headerHeight,
          decoration: BoxDecoration(
            color: bg,
            border: Border(
              right: const BorderSide(
                color: LoggerColors.borderSubtle,
                width: 1,
              ),
              bottom: widget.isSelected
                  ? BorderSide(color: poolColor, width: 2)
                  : BorderSide.none,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: _buttonHPadding),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: _sessionDotSize,
                height: _sessionDotSize,
                decoration: BoxDecoration(
                  color: poolColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  widget.session.application.name,
                  style: LoggerTypography.headerBtn.copyWith(color: textColor),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
