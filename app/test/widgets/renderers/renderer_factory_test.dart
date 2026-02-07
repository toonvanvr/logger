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

LogEntry _makeEntry(LogType type) {
  return LogEntry(
    id: 'e1',
    timestamp: '2026-02-07T10:00:00.000Z',
    sessionId: 'sess-1',
    severity: Severity.info,
    type: type,
    text: 'test',
    jsonData: type == LogType.json ? <String, dynamic>{} : null,
    html: type == LogType.html ? '<p>hi</p>' : null,
    binary: type == LogType.binary ? 'AQID' : null,
    groupAction: type == LogType.group ? GroupAction.open : null,
    groupLabel: type == LogType.group ? 'G' : null,
    sessionAction: type == LogType.session ? SessionAction.start : null,
    application: type == LogType.session
        ? const ApplicationInfo(name: 'App')
        : null,
    rpcDirection: type == LogType.rpc ? RpcDirection.request : null,
    rpcMethod: type == LogType.rpc ? 'ping' : null,
  );
}

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
  final cases = <LogType, Type>{
    LogType.text: TextRenderer,
    LogType.json: JsonRenderer,
    LogType.html: HtmlRenderer,
    LogType.binary: BinaryRenderer,
    LogType.image: ImageRenderer,
    LogType.state: StateRenderer,
    LogType.group: GroupRenderer,
    LogType.rpc: RpcRenderer,
    LogType.session: SessionRenderer,
    LogType.custom: CustomRenderer,
  };

  for (final entry in cases.entries) {
    testWidgets(
      'buildLogContent returns ${entry.value} for ${entry.key.name}',
      (tester) async {
        final widget = buildLogContent(_makeEntry(entry.key));
        expect(widget.runtimeType, entry.value);

        // Also verify it renders without errors.
        await tester.pumpWidget(_wrap(widget));
      },
    );
  }
}
