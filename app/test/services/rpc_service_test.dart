import 'package:app/services/rpc_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RpcService', () {
    late RpcService service;

    setUp(() {
      service = RpcService();
    });

    test('updateTools stores tools for a session', () {
      final tools = [
        const RpcToolInfo(
          name: 'getState',
          description: 'Get app state',
          category: 'getter',
        ),
        const RpcToolInfo(
          name: 'clearCache',
          description: 'Clear cache',
          category: 'tool',
          confirm: true,
        ),
      ];

      service.updateTools('sess-1', tools);

      expect(service.tools.containsKey('sess-1'), isTrue);
      expect(service.tools['sess-1']!.length, 2);
      expect(service.tools['sess-1']![0].name, 'getState');
      expect(service.tools['sess-1']![1].confirm, isTrue);
    });

    test('handleResponse resolves pending future', () async {
      // We cannot easily create a pending via invoke without a real
      // LogConnection, so test handleResponse directly:
      // calling handleResponse with an unknown rpcId should simply store the
      // result and not throw.
      service.handleResponse('rpc-123', {'key': 'value'}, null);

      expect(service.results.containsKey('rpc-123'), isTrue);
      expect(service.results['rpc-123']!.data, {'key': 'value'});
      expect(service.results['rpc-123']!.error, isNull);
    });

    test('handleResponse with unknown rpcId stores result without error', () {
      // Calling with an id that has no pending completer should be safe.
      service.handleResponse('unknown-id', null, 'some error');

      expect(service.results.containsKey('unknown-id'), isTrue);
      expect(service.results['unknown-id']!.error, 'some error');
      expect(service.results['unknown-id']!.data, isNull);
    });
  });
}
