import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/server_broadcast.dart';
import '../../services/session_store.dart';
import '../../theme/colors.dart';
import '../../theme/constants.dart';
import '../../theme/typography.dart';

const _headerHeight = 40.0;
const _sessionDotSize = 6.0;

/// Overflow "···" button that shows all sessions in a dropdown overlay.
class OverflowButton extends StatefulWidget {
  final List<SessionInfo> overflowSessions;
  const OverflowButton({super.key, required this.overflowSessions});

  @override
  State<OverflowButton> createState() => _OverflowButtonState();
}

class _OverflowButtonState extends State<OverflowButton> {
  OverlayEntry? _overlayEntry;

  void _showOverflowMenu() {
    _removeOverlay();
    final sessionStore = context.read<SessionStore>();
    final box = context.findRenderObject()! as RenderBox;
    final position = box.localToGlobal(Offset.zero);

    _overlayEntry = OverlayEntry(
      builder: (_) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _removeOverlay,
              behavior: HitTestBehavior.opaque,
              child: const ColoredBox(color: Colors.transparent),
            ),
          ),
          Positioned(
            left: position.dx,
            top: position.dy + _headerHeight,
            child: Material(
              color: LoggerColors.bgOverlay,
              elevation: 8,
              borderRadius: kBorderRadius,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxHeight: 300,
                  maxWidth: 250,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: widget.overflowSessions.length,
                  itemBuilder: (ctx, i) => _buildSessionTile(
                    widget.overflowSessions[i],
                    sessionStore,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry?.dispose();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  Widget _buildSessionTile(SessionInfo session, SessionStore sessionStore) {
    final selected = sessionStore.isSelected(session.sessionId);
    final poolColor = LoggerColors
        .sessionPool[session.colorIndex % LoggerColors.sessionPool.length];
    return InkWell(
      onTap: () {
        sessionStore.toggleSession(session.sessionId);
        _removeOverlay();
      },
      child: SizedBox(
        height: 28,
        child: Padding(
          padding: kHPadding8,
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
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _showOverflowMenu,
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
}
