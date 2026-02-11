import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/session_store.dart';
import '../../theme/colors.dart';

/// Small 6px colored circle indicating the session an entry belongs to.
class SessionDot extends StatelessWidget {
  final String sessionId;

  const SessionDot({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context) {
    final colorIndex = context.select<SessionStore, int>(
      (s) => s.getSession(sessionId)?.colorIndex ?? 0,
    );
    final color =
        LoggerColors.sessionPool[colorIndex % LoggerColors.sessionPool.length];

    return Center(
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}
