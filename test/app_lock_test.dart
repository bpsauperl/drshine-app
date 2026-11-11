import 'package:drshine/auth/device_unlock.dart';
import 'package:drshine/state/app_lock.dart';
import 'package:drshine/state/session_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';

/// A Wednesday morning in winter: 10:00 in Ljubljana.
final _morning = DateTime.utc(2026, 11, 11, 9);

void _lifecycle(WidgetTester tester, List<AppLifecycleState> states) {
  for (final state in states) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
}

/// The app goes to the background, as on a phone: inactive, hidden, paused.
Future<void> leaveApp(WidgetTester tester) async {
  addTearDown(
    () => tester.binding.handleAppLifecycleStateChanged(
      AppLifecycleState.resumed,
    ),
  );
  _lifecycle(tester, const [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
  ]);
  await tester.pump();
}

/// The app comes to the front again.
Future<void> returnToApp(WidgetTester tester) async {
  _lifecycle(tester, const [
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]);
  await tester.pumpAndSettle();
}

Future<void> signInWithSmileId(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('smileid')));
  await tester.pumpAndSettle();
}

Future<void> tapUnlock(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('unlock')));
  await tester.pumpAndSettle();
}

void expectLocked() {
  expect(find.text('drShine is locked.'), findsOneWidget);
  expect(find.text('Patients'), findsNothing);
  expect(find.text('Test Patient'), findsNothing);
}

void expectOpen() {
  expect(find.text('drShine is locked.'), findsNothing);
  expect(find.text('Test Patient'), findsOneWidget);
}

void main() {
  group('The app lock', () {
    testWidgets('a saved session opens locked, and the phone unlocks it', (
      tester,
    ) async {
      final store = MemorySessionStore(
        token: 'saved',
        lastUnlock: _morning.subtract(const Duration(minutes: 1)),
      );
      final unlock = FakeDeviceUnlock()..answer = UnlockResult.notUnlocked;
      await pumpApp(
        tester,
        FakeApi(),
        store,
        unlock: unlock,
        clock: () => _morning,
      );

      expectLocked();
      expect(unlock.asked, 1);

      unlock.answer = UnlockResult.unlocked;
      await tapUnlock(tester);

      expectOpen();
      expect(unlock.asked, 2);
      expect(store.lastUnlock, _morning);
    });

    testWidgets('signing in with SmileID does not ask', (tester) async {
      final store = MemorySessionStore();
      final unlock = FakeDeviceUnlock();
      await pumpApp(
        tester,
        FakeApi(),
        store,
        unlock: unlock,
        clock: () => _morning,
      );

      await signInWithSmileId(tester);

      expectOpen();
      expect(unlock.asked, 0);
      expect(store.lastUnlock, _morning);
    });

    testWidgets('a short time away is covered, and does not ask', (
      tester,
    ) async {
      var now = _morning;
      final unlock = FakeDeviceUnlock();
      await pumpApp(
        tester,
        FakeApi(),
        MemorySessionStore(),
        unlock: unlock,
        clock: () => now,
      );
      await signInWithSmileId(tester);

      // Something over the app (the app switcher, a system prompt).
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(find.text('Test Patient'), findsNothing);
      expect(find.text('drShine is locked.'), findsNothing);

      await leaveApp(tester);
      now = now.add(const Duration(minutes: 14, seconds: 59));
      await returnToApp(tester);

      expectOpen();
      expect(unlock.asked, 0);
    });

    testWidgets('15 minutes away asks', (tester) async {
      var now = _morning;
      final unlock = FakeDeviceUnlock()..answer = UnlockResult.notUnlocked;
      await pumpApp(
        tester,
        FakeApi(),
        MemorySessionStore(),
        unlock: unlock,
        clock: () => now,
      );
      await signInWithSmileId(tester);

      await leaveApp(tester);
      now = now.add(const Duration(minutes: 15));
      await returnToApp(tester);

      expectLocked();
      expect(unlock.asked, 1);

      // A lock screen that is already up waits for the button.
      await leaveApp(tester);
      await returnToApp(tester);
      expectLocked();
      expect(unlock.asked, 1);

      unlock.answer = UnlockResult.unlocked;
      await tapUnlock(tester);
      expectOpen();
    });

    testWidgets('the first return after 04:00 in Ljubljana asks, once', (
      tester,
    ) async {
      // 03:58 in Ljubljana.
      var now = DateTime.utc(2026, 11, 11, 2, 58);
      final unlock = FakeDeviceUnlock();
      await pumpApp(
        tester,
        FakeApi(),
        MemorySessionStore(),
        unlock: unlock,
        clock: () => now,
      );
      await signInWithSmileId(tester);

      await leaveApp(tester);
      now = DateTime.utc(2026, 11, 11, 3, 1);
      await returnToApp(tester);

      expect(unlock.asked, 1);
      expectOpen();

      await leaveApp(tester);
      now = now.add(const Duration(minutes: 5));
      await returnToApp(tester);

      expect(unlock.asked, 1);
      expectOpen();
    });

    testWidgets('a screen that was open is there again after unlocking', (
      tester,
    ) async {
      var now = _morning;
      final unlock = FakeDeviceUnlock()..answer = UnlockResult.notUnlocked;
      await pumpApp(
        tester,
        FakeApi(),
        MemorySessionStore(),
        unlock: unlock,
        clock: () => now,
      );
      await signInWithSmileId(tester);
      tester
          .state<NavigatorState>(find.byType(Navigator))
          .push(
            MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('A patient')),
            ),
          );
      await tester.pumpAndSettle();

      await leaveApp(tester);
      now = now.add(const Duration(hours: 1));
      await returnToApp(tester);

      expect(find.text('drShine is locked.'), findsOneWidget);
      expect(find.text('A patient'), findsNothing);

      unlock.answer = UnlockResult.unlocked;
      await tapUnlock(tester);

      expect(find.text('A patient'), findsOneWidget);
    });

    testWidgets('Sign out on the lock screen goes to sign-in', (tester) async {
      final store = MemorySessionStore(token: 'saved', lastUnlock: _morning);
      final unlock = FakeDeviceUnlock()..answer = UnlockResult.notUnlocked;
      await pumpApp(
        tester,
        FakeApi(),
        store,
        unlock: unlock,
        clock: () => _morning,
      );
      expectLocked();

      await tester.tap(find.byKey(const Key('lock-sign-out')));
      await tester.pumpAndSettle();

      expect(find.text('Welcome back.'), findsOneWidget);
      expect(find.text('drShine is locked.'), findsNothing);
      expect(store.token, isNull);
      expect(store.lastUnlock, isNull);
    });

    testWidgets('a session the server ends while locked shows sign-in', (
      tester,
    ) async {
      const sentence = 'Your SmileID session has ended. Please sign in again.';
      final unlock = FakeDeviceUnlock()..answer = UnlockResult.notUnlocked;
      final state = await pumpApp(
        tester,
        FakeApi(),
        MemorySessionStore(token: 'saved'),
        unlock: unlock,
        clock: () => _morning,
      );
      expectLocked();

      await state.sessionExpired(sentence);
      await tester.pumpAndSettle();

      expect(find.text('Welcome back.'), findsOneWidget);
      expect(find.text(sentence), findsOneWidget);
      expect(find.text('drShine is locked.'), findsNothing);
    });
  });

  group('A phone with no screen lock', () {
    testWidgets('opens during the day, and signs in again in the morning', (
      tester,
    ) async {
      var now = _morning;
      final store = MemorySessionStore();
      final unlock = FakeDeviceUnlock()..screenLock = false;
      await pumpApp(tester, FakeApi(), store, unlock: unlock, clock: () => now);
      await signInWithSmileId(tester);

      await leaveApp(tester);
      now = now.add(const Duration(hours: 2));
      await returnToApp(tester);

      expectOpen();

      await leaveApp(tester);
      now = DateTime.utc(2026, 11, 12, 6);
      await returnToApp(tester);

      expect(find.text('Welcome back.'), findsOneWidget);
      expect(find.text(noScreenLockSentence), findsOneWidget);
      expect(find.text('Test Patient'), findsNothing);
      expect(store.token, isNull);
      expect(unlock.asked, 0);
    });

    testWidgets('opens when the app is started again the same day', (
      tester,
    ) async {
      final store = MemorySessionStore(
        token: 'saved',
        lastUnlock: _morning.subtract(const Duration(hours: 3)),
      );
      final unlock = FakeDeviceUnlock()..screenLock = false;
      await pumpApp(
        tester,
        FakeApi(),
        store,
        unlock: unlock,
        clock: () => _morning,
      );

      expectOpen();
      expect(store.token, 'saved');
    });

    testWidgets('signs in again when the app is started the next morning', (
      tester,
    ) async {
      final store = MemorySessionStore(
        token: 'saved',
        lastUnlock: _morning.subtract(const Duration(hours: 12)),
      );
      final unlock = FakeDeviceUnlock()..screenLock = false;
      await pumpApp(
        tester,
        FakeApi(),
        store,
        unlock: unlock,
        clock: () => _morning,
      );

      expect(find.text('Welcome back.'), findsOneWidget);
      expect(find.text(noScreenLockSentence), findsOneWidget);
      expect(store.token, isNull);
    });

    testWidgets('a screen lock removed while locked follows the same rule', (
      tester,
    ) async {
      final store = MemorySessionStore(token: 'saved', lastUnlock: _morning);
      final unlock = FakeDeviceUnlock()..answer = UnlockResult.notUnlocked;
      await pumpApp(
        tester,
        FakeApi(),
        store,
        unlock: unlock,
        clock: () => _morning,
      );
      expectLocked();

      unlock.screenLock = false;
      await tapUnlock(tester);

      expectOpen();
    });
  });

  group('04:00 in Ljubljana', () {
    test('in winter it is 03:00 UTC', () {
      expect(
        ljubljanaDayStart(DateTime.utc(2026, 11, 11, 10)),
        DateTime.utc(2026, 11, 11, 3),
      );
      expect(
        ljubljanaDayStart(DateTime.utc(2026, 11, 11, 3)),
        DateTime.utc(2026, 11, 11, 3),
      );
    });

    test('before 04:00 the day is still yesterday', () {
      expect(
        ljubljanaDayStart(DateTime.utc(2026, 11, 11, 2, 59)),
        DateTime.utc(2026, 11, 10, 3),
      );
      // 00:30 in Ljubljana on New Year's Day.
      expect(
        ljubljanaDayStart(DateTime.utc(2026, 12, 31, 23, 30)),
        DateTime.utc(2026, 12, 31, 3),
      );
    });

    test('in summer it is 02:00 UTC', () {
      expect(
        ljubljanaDayStart(DateTime.utc(2026, 7, 1, 12)),
        DateTime.utc(2026, 7, 1, 2),
      );
      expect(
        ljubljanaDayStart(DateTime.utc(2026, 7, 1, 1, 59)),
        DateTime.utc(2026, 6, 30, 2),
      );
    });

    test('on the day the clocks go forward', () {
      // Sunday 28 March 2027: 02:00 becomes 03:00, at 01:00 UTC.
      expect(
        ljubljanaDayStart(DateTime.utc(2027, 3, 28, 1, 30)),
        DateTime.utc(2027, 3, 27, 3),
      );
      expect(
        ljubljanaDayStart(DateTime.utc(2027, 3, 28, 2)),
        DateTime.utc(2027, 3, 28, 2),
      );
    });

    test('on the day the clocks go back', () {
      // Sunday 25 October 2026: 03:00 becomes 02:00, at 01:00 UTC.
      expect(
        ljubljanaDayStart(DateTime.utc(2026, 10, 25, 2, 30)),
        DateTime.utc(2026, 10, 24, 2),
      );
      expect(
        ljubljanaDayStart(DateTime.utc(2026, 10, 25, 3)),
        DateTime.utc(2026, 10, 25, 3),
      );
    });

    test('a phone in another time zone gets the same answer', () {
      final local = DateTime.utc(2026, 11, 11, 10).toLocal();
      expect(ljubljanaDayStart(local), DateTime.utc(2026, 11, 11, 3));
    });
  });
}
