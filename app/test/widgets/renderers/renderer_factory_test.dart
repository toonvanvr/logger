import 'package:app/models/log_entry.dart';
import 'package:app/services/session_store.dart';
import 'package:app/theme/theme.dart';
import 'package:app/widgets/renderers/binary_renderer.dart';
import 'package:app/widgets/renderers/custom_renderer.dart';
import 'package:app/widgets/renderers/group_renderer.dart';
import 'package:app/widgets/renderers/html_renderer.dart';
import 'package:app/widgets/renderers/image_renderer.dart';
import 'package:app/widgets/renderers/json_renderer.dart';
import 'package:app/widgets/renderers/renderer_factory.dart';
import 'package:app/widgets/renderers/rpc_renderer.dart';
import 'package:app/widgets/renderers/session_renderer.dart';
import 'package:app/widgets/renderers/state_renderer.dart';
import 'package:app/widgets/renderers/text_renderer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../test_helpers.dart';

Widget _wrap(Widget child) {
  return MultiProvider(
    providers: [ChangeNotifierProvider(create: (_) => SessionStore())],
    child: MaterialApp(
      theme: createLoggerTheme(),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

void main() {
  final cases = <String, (LogEntry, Type)>{
    'text': (
      makeTestEntry(kind: EntryKind.event, message: 'test'),
      TextRenderer,
    ),
    'json': (
      makeTestEntry(
        kind: EntryKind.event,
        widget: const WidgetPayload(type: 'json', data: {'data': {}}),
      ),
      JsonRenderer,
    ),
    'html': (
      makeTestEntry(
        kind: EntryKind.event,
        widget: const WidgetPayload(
          type: 'html',
          data: {'content': '<p>hi</p>'},
        ),
      ),
      HtmlRenderer,
    ),
    'binary': (
      makeTestEntry(
        kind: EntryKind.event,
        widget: const WidgetPayload(
          type: 'binary',
          data: {'data': 'AQID'},
        ),
      ),
      BinaryRenderer,
    ),
    'image': (
      makeTestEntry(
        kind: EntryKind.event,
        widget: const WidgetPayload(
          type: 'image',
          data: {'ref': 'https://example.com/image.png'},
        ),
      ),
      ImageRenderer,
    ),
    'state': (
      makeTestEntry(kind: EntryKind.data, key: 'k', value: 'v'),
      StateRenderer,
    ),
    'group': (
      makeTestEntry(kind: EntryKind.event, groupId: 'g1', message: 'G'),
      GroupRenderer,
    ),
    'rpc': (
      makeTestEntry(
        kind: EntryKind.event,
        widget: const WidgetPayload(
          type: 'rpc_request',
          data: {'direction': 'request', 'method': 'ping'},
        ),
      ),
      RpcRenderer,
    ),
    'session': (
      makeTestEntry(
        kind: EntryKind.session,
        sessionAction: SessionAction.start,
        application: const ApplicationInfo(name: 'App'),
      ),
      SessionRenderer,
    ),
    'custom': (
      makeTestEntry(
        kind: EntryKind.event,
        widget: const WidgetPayload(type: 'metric', data: {}),
      ),
      CustomRenderer,
    ),
  };

  for (final entry in cases.entries) {
    testWidgets(
      'buildLogContent returns ${entry.value.$2} for ${entry.key}',
      (tester) async {
        final widget = buildLogContent(entry.value.$1);
        expect(widget.runtimeType, entry.value.$2);

        // Also verify it renders without errors.
        await tester.pumpWidget(_wrap(widget));
      },
    );
  }
}
