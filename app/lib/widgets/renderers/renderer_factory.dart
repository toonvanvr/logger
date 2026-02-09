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
/// If the entry has an [ExceptionData] exception and is not rendered
/// by [TextRenderer] (which handles exceptions internally), a
/// [StackTraceRenderer] is appended below the main content.
Widget buildLogContent(LogEntry entry) {
  final mainWidget = _buildMainContent(entry);

  // TextRenderer already handles exceptions internally.
  final usesTextRenderer =
      entry.kind == EntryKind.event &&
      entry.widget == null &&
      entry.groupId == null &&
      entry.parentId == null;

  if (entry.exception != null && !usesTextRenderer) {
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
  switch (entry.kind) {
    case EntryKind.session:
      return SessionRenderer(entry: entry);
    case EntryKind.data:
      return StateRenderer(entry: entry);
    case EntryKind.event:
      if (entry.widget != null) {
        return switch (entry.widget!.type) {
          'json' => JsonRenderer(entry: entry),
          'html' => HtmlRenderer(entry: entry),
          'binary' => BinaryRenderer(entry: entry),
          'image' => ImageRenderer(entry: entry),
          'rpc' ||
          'rpc_request' ||
          'rpc_response' ||
          'rpc_error' => RpcRenderer(entry: entry),
          _ => CustomRenderer(entry: entry),
        };
      }
      if (entry.parentId != null || entry.groupId != null) {
        return GroupRenderer(entry: entry);
      }
      return TextRenderer(entry: entry);
  }
}
