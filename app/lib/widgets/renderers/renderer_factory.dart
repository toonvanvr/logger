import 'package:flutter/material.dart';

import '../../models/log_entry.dart';
import 'binary_renderer.dart';
import 'custom_renderer.dart';
import 'group_renderer.dart';
import 'html_renderer.dart';
import 'image_renderer.dart';
import 'json_renderer.dart';
import 'rpc_renderer.dart';
import 'session_renderer.dart';
import 'stack_trace_renderer.dart';
import 'state_renderer.dart';
import 'text_renderer.dart';

/// Returns the appropriate content renderer widget for [entry].
///
/// If the entry has an [ExceptionData] exception, a [StackTraceRenderer]
/// is appended below the main content.
Widget buildLogContent(LogEntry entry) {
  final mainWidget = _buildMainContent(entry);

  if (entry.exception != null && entry.type != LogType.text) {
    // TextRenderer already handles exceptions internally
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        mainWidget,
        const SizedBox(height: 4),
        StackTraceRenderer(exception: entry.exception!),
      ],
    );
  }

  return mainWidget;
}

Widget _buildMainContent(LogEntry entry) {
  switch (entry.type) {
    case LogType.text:
      return TextRenderer(entry: entry);
    case LogType.json:
      return JsonRenderer(entry: entry);
    case LogType.html:
      return HtmlRenderer(entry: entry);
    case LogType.binary:
      return BinaryRenderer(entry: entry);
    case LogType.image:
      return ImageRenderer(entry: entry);
    case LogType.state:
      return StateRenderer(entry: entry);
    case LogType.group:
      return GroupRenderer(entry: entry);
    case LogType.rpc:
      return RpcRenderer(entry: entry);
    case LogType.session:
      return SessionRenderer(entry: entry);
    case LogType.custom:
      return CustomRenderer(entry: entry);
  }
}
