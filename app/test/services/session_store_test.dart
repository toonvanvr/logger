import 'package:app/models/log_entry.dart';
import 'package:app/models/server_broadcast.dart';
import 'package:app/services/session_store.dart';
import 'package:flutter_test/flutter_test.dart';

SessionInfo _makeSession({
  required String sessionId,
  String appName = 'TestApp',
  bool isActive = true,
  int colorIndex = 0,
}) {
  return SessionInfo(
    sessionId: sessionId,
    application: ApplicationInfo(name: appName),
    startedAt: '2026-02-07T12:00:00Z',
    lastHeartbeat: '2026-02-07T12:01:00Z',
    isActive: isActive,
    logCount: 0,
    colorIndex: colorIndex,
  );
}

void main() {
  group('SessionStore', () {
    late SessionStore store;

    setUp(() {
      store = SessionStore();
    });

    // ── Test 16: updateSession adds new session ──

    test('updateSession adds new session', () {
      store.updateSession(_makeSession(sessionId: 'sess-1'));

      expect(store.sessions.length, 1);
      expect(store.getSession('sess-1'), isNotNull);
      expect(store.getSession('sess-1')!.sessionId, 'sess-1');
    });

    // ── Test 17: updateSessions adds multiple sessions ──

    test('updateSessions adds multiple sessions', () {
      store.updateSessions([
        _makeSession(sessionId: 'sess-1'),
        _makeSession(sessionId: 'sess-2'),
        _makeSession(sessionId: 'sess-3'),
      ]);

      expect(store.sessions.length, 3);
    });

    // ── Test 18: toggleSession selects then deselects ──

    test('toggleSession selects then deselects', () {
      store.updateSession(_makeSession(sessionId: 'sess-1'));

      store.toggleSession('sess-1');
      expect(store.isSelected('sess-1'), isTrue);

      store.toggleSession('sess-1');
      expect(store.isSelected('sess-1'), isFalse);
    });

    // ── Test 19: selectOnly selects one, deselects rest ──

    test('selectOnly selects one and deselects rest', () {
      store.updateSessions([
        _makeSession(sessionId: 'sess-1'),
        _makeSession(sessionId: 'sess-2'),
      ]);
      store.toggleSession('sess-1');
      store.toggleSession('sess-2');

      store.selectOnly('sess-1');

      expect(store.isSelected('sess-1'), isTrue);
      expect(store.isSelected('sess-2'), isFalse);
      expect(store.selectedSessionIds.length, 1);
    });

    // ── Test 20: selectOnly same session twice deselects ──

    test('selectOnly same session twice deselects', () {
      store.updateSession(_makeSession(sessionId: 'sess-1'));

      store.selectOnly('sess-1');
      expect(store.isSelected('sess-1'), isTrue);

      store.selectOnly('sess-1');
      expect(store.isSelected('sess-1'), isFalse);
      expect(store.selectedSessionIds, isEmpty);
    });

    // ── Test 21: selectAll selects all known sessions ──

    test('selectAll selects all known sessions', () {
      store.updateSessions([
        _makeSession(sessionId: 'sess-1'),
        _makeSession(sessionId: 'sess-2'),
        _makeSession(sessionId: 'sess-3'),
      ]);

      store.selectAll();

      expect(store.selectedSessionIds.length, 3);
      expect(store.isSelected('sess-1'), isTrue);
      expect(store.isSelected('sess-2'), isTrue);
      expect(store.isSelected('sess-3'), isTrue);
    });

    // ── Test 22: deselectAll clears selection ──

    test('deselectAll clears selection', () {
      store.updateSessions([
        _makeSession(sessionId: 'sess-1'),
        _makeSession(sessionId: 'sess-2'),
      ]);
      store.selectAll();

      store.deselectAll();

      expect(store.selectedSessionIds, isEmpty);
    });

    // ── Test 23: getSession returns null for unknown ID ──

    test('getSession returns null for unknown ID', () {
      expect(store.getSession('nonexistent'), isNull);
    });

    // ── Additional: updateSession calls notifyListeners ──

    test('updateSession calls notifyListeners', () {
      var notified = false;
      store.addListener(() => notified = true);

      store.updateSession(_makeSession(sessionId: 'sess-1'));

      expect(notified, isTrue);
    });
  });
}
