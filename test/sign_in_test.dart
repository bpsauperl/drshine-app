import 'package:drshine/state/session_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';

void main() {
  testWidgets('signs in with email and password, then shows Patients', (
    tester,
  ) async {
    final api = FakeApi();
    final store = MemorySessionStore();
    await pumpApp(tester, api, store);

    expect(find.text('Welcome back.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('sign-in')));
    await tester.pump();
    expect(find.text('Enter your email and password.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('email')),
      'doctor@drshine.test',
    );
    await tester.enterText(find.byKey(const Key('password')), 'example');
    await tester.tap(find.byKey(const Key('sign-in')));
    await tester.pumpAndSettle();

    expect(find.text('Patients'), findsOneWidget);
    expect(find.text('Test Patient'), findsOneWidget);
    expect(store.token, 'token-1');
    expect(store.lastEmail, 'doctor@drshine.test');
  });

  testWidgets('asks for the 6-digit code when two-step is on', (tester) async {
    final api = FakeApi()..twoFactor = true;
    final store = MemorySessionStore();
    await pumpApp(tester, api, store);

    await tester.enterText(
      find.byKey(const Key('email')),
      'doctor@drshine.test',
    );
    await tester.enterText(find.byKey(const Key('password')), 'example');
    await tester.tap(find.byKey(const Key('sign-in')));
    await tester.pumpAndSettle();

    expect(find.text('One more step.'), findsOneWidget);
    expect(find.byKey(const Key('password')), findsNothing);
    expect(store.token, isNull);

    await tester.enterText(find.byKey(const Key('code')), '123456');
    await tester.tap(find.byKey(const Key('sign-in')));
    await tester.pumpAndSettle();

    expect(api.lastCode, '123456');
    expect(find.text('Patients'), findsOneWidget);
    expect(store.token, 'token-2');
  });

  testWidgets('the server address can be changed and is remembered', (
    tester,
  ) async {
    final api = FakeApi();
    final store = MemorySessionStore();
    await pumpApp(tester, api, store);

    await tester.ensureVisible(find.byKey(const Key('server-toggle')));
    await tester.tap(find.byKey(const Key('server-toggle')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('server')),
      'http://127.0.0.1:8030',
    );
    await tester.enterText(
      find.byKey(const Key('email')),
      'doctor@drshine.test',
    );
    await tester.enterText(find.byKey(const Key('password')), 'example');
    await tester.ensureVisible(find.byKey(const Key('sign-in')));
    await tester.tap(find.byKey(const Key('sign-in')));
    await tester.pumpAndSettle();

    expect(api.baseUrl, 'http://127.0.0.1:8030');
    expect(store.serverUrl, 'http://127.0.0.1:8030');
  });

  testWidgets('a saved token goes straight to Patients', (tester) async {
    final store = MemorySessionStore(token: 'saved');
    await pumpApp(tester, FakeApi(), store);
    expect(find.text('Patients'), findsOneWidget);
  });
}
