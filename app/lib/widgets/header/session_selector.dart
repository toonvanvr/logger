import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/server_message.dart';
import '../../services/log_connection.dart';
import '../../services/session_store.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';

const _headerHeight = 40.0;
const _maxVisibleSessions = 8;
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
    final visible = sessions.length > _maxVisibleSessions
        ? sessions.sublist(0, _maxVisibleSessions)
        : sessions;
    final hasOverflow = sessions.length > _maxVisibleSessions;

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
          // Session buttons (bounded to available space, scrollable)
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final session in visible)
                  SessionButton(
                    session: session,
                    isSelected: sessionStore.isSelected(session.sessionId),
                    onTap: () => sessionStore.selectOnly(session.sessionId),
                    onCtrlTap: () =>
                        sessionStore.toggleSession(session.sessionId),
                  ),
              ],
            ),
          ),
          // Overflow button (outside scroll area, always visible)
          if (hasOverflow) _OverflowButton(sessions: sessions),
          // Filter toggle
          _HeaderIconButton(
            icon: Icons.filter_list,
            tooltip: 'Toggle filters',
            isActive: isFilterExpanded,
            onTap: onFilterToggle,
          ),
          // RPC panel toggle
          _HeaderIconButton(
            icon: Icons.build_outlined,
            tooltip: 'Toggle tools panel',
            isActive: false,
            onTap: onRpcToggle,
          ),
          const SizedBox(width: 4),
          // Connection indicator
          _ConnectionIndicator(isConnected: connection.isConnected),
          const SizedBox(width: 8),
          // Always-on-top toggle
          const _AlwaysOnTopButton(),
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

// --- Private helper widgets ---

class _OverflowButton extends StatelessWidget {
  final List<SessionInfo> sessions;
  const _OverflowButton({required this.sessions});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showOverflowMenu(context),
      child: Container(
        width: 28,
        height: _headerHeight,
        alignment: Alignment.center,
        child: Text(
          '···',
          style: LoggerTypography.headerBtn.copyWith(
            color: LoggerColors.fgMuted,
          ),
        ),
      ),
    );
  }

  void _showOverflowMenu(BuildContext context) {
    final sessionStore = context.read<SessionStore>();
    final box = context.findRenderObject()! as RenderBox;
    final position = box.localToGlobal(Offset.zero);

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy + _headerHeight,
        position.dx + 28,
        position.dy + _headerHeight,
      ),
      color: LoggerColors.bgOverlay,
      items: sessions.map((session) {
        final selected = sessionStore.isSelected(session.sessionId);
        final poolColor = LoggerColors
            .sessionPool[session.colorIndex % LoggerColors.sessionPool.length];
        return PopupMenuItem<String>(
          value: session.sessionId,
          height: 28,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? Icons.check_box : Icons.check_box_outline_blank,
                size: 14,
                color: selected ? LoggerColors.fgPrimary : LoggerColors.fgMuted,
              ),
              const SizedBox(width: 6),
              Container(
                width: _sessionDotSize,
                height: _sessionDotSize,
                decoration: BoxDecoration(
                  color: poolColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  session.application.name,
                  style: LoggerTypography.headerBtn,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    ).then((sessionId) {
      if (sessionId != null) {
        sessionStore.toggleSession(sessionId);
      }
    });
  }
}

class _ConnectionIndicator extends StatelessWidget {
  final bool isConnected;
  const _ConnectionIndicator({required this.isConnected});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: isConnected ? 'Connected' : 'Disconnected',
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: isConnected
              ? const Color(0xFFA8CC7E)
              : const Color(0xFFE06C60),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final bool isActive;
  final VoidCallback? onTap;

  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    this.isActive = false,
    this.onTap,
  });

  @override
  State<_HeaderIconButton> createState() => _HeaderIconButtonState();
}

class _HeaderIconButtonState extends State<_HeaderIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Tooltip(
        message: widget.tooltip,
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: 28,
            height: _headerHeight,
            alignment: Alignment.center,
            color: _hovered ? LoggerColors.bgHover : Colors.transparent,
            child: Icon(
              widget.icon,
              size: 14,
              color: widget.isActive
                  ? LoggerColors.borderFocus
                  : LoggerColors.fgMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _AlwaysOnTopButton extends StatefulWidget {
  const _AlwaysOnTopButton();

  @override
  State<_AlwaysOnTopButton> createState() => _AlwaysOnTopButtonState();
}

class _AlwaysOnTopButtonState extends State<_AlwaysOnTopButton> {
  bool _pinned = false;

  @override
  Widget build(BuildContext context) {
    return _HeaderIconButton(
      icon: Icons.push_pin_outlined,
      tooltip: 'Always on top',
      isActive: _pinned,
      onTap: () => setState(() => _pinned = !_pinned),
    );
  }
}
