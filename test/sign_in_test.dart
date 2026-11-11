import 'package:drshine/api/api_client.dart';
import 'package:drshine/auth/browser_sign_in.dart';
import 'package:drshine/state/session_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';

void main() {
  group('Sign in with SmileID', () {
    testWidgets('stores the token and shows Patients', (tester) async {
      final api = FakeApi();
      final store = MemorySessionStore();
      final browser = FakeBrowserSignIn(api);
      await pumpApp(tester, api, store, browser: browser);

      expect(find.text('Welcome back.'), findsOneWidget);
      expect(find.text('Sign in with SmileID'), findsOneWidget);
      expect(
        find.text(
          'Face ID, Touch ID or a code by email. One account for every SmileLabs app.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('smileid')));
      await tester.pumpAndSettle();

      expect(find.text('Patients'), findsOneWidget);
      expect(find.text('Test Patient'), findsOneWidget);
      expect(store.token, 'token-smileid');
      expect(store.lastEmail, 'doctor@drshine.test');

      final link = browser.opened.single;
      expect(link.toString(), startsWith('$defaultServerUrl/app/sign-in?'));
      expect(link.queryParameters['challenge'], hasLength(43));
      expect(
        link.queryParameters['challenge'],
        challengeFor(api.lastVerifier!),
      );
      expect(link.queryParameters['device'], 'drShine on Android');
      expect(link.queryParameters.containsKey('email'), isFalse);
      expect(link.queryParameters.containsKey('switch'), isFalse);
    });

    testWidgets('the last email goes along, and not for another SmileID', (
      tester,
    ) async {
      final api = FakeApi();
      final browser = FakeBrowserSignIn(api)..closes = true;
      await pumpApp(
        tester,
        api,
        MemorySessionStore(lastEmail: 'doctor@drshine.test'),
        browser: browser,
      );

      await tester.tap(find.byKey(const Key('smileid')));
      await tester.pumpAndSettle();
      expect(
        browser.opened.last.queryParameters['email'],
        'doctor@drshine.test',
      );
      expect(
        browser.opened.last.queryParameters.containsKey('switch'),
        isFalse,
      );

      await tester.tap(find.byKey(const Key('smileid-another')));
      await tester.pumpAndSettle();
      expect(browser.opened.last.queryParameters['switch'], '1');
      expect(browser.opened.last.queryParameters.containsKey('email'), isFalse);
    });

    testWidgets('closing the sheet shows no error', (tester) async {
      final api = FakeApi();
      final store = MemorySessionStore();
      final browser = FakeBrowserSignIn(api)..closes = true;
      await pumpApp(tester, api, store, browser: browser);

      await tester.tap(find.byKey(const Key('smileid')));
      await tester.pumpAndSettle();

      expect(browser.opened, hasLength(1));
      expect(find.text('Welcome back.'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsNothing);
      expect(find.byIcon(Icons.info_outline), findsNothing);
      expect(store.token, isNull);
    });

    const sentences = {
      'not_finished':
          "Signing in with SmileID didn't finish. Please try again.",
      'switched_off': 'This SmileID is switched off.',
      'no_account': "There is no drShine account for this SmileID. Your clinic's director can invite you.",
      'clinic_off': "This clinic's account is switched off. Contact SmileLabs.",
      'not_ready': "Sign in with SmileID isn't ready on this server yet.",
      'something_new':
          "Signing in with SmileID didn't finish. Please try again.",
    };
    for (final MapEntry(key: code, value: sentence) in sentences.entries) {
      testWidgets('the error code $code shows its sentence', (tester) async {
        final api = FakeApi();
        final store = MemorySessionStore();
        await pumpApp(
          tester,
          api,
          store,
          browser: FakeBrowserSignIn(api)..error = code,
        );

        await tester.tap(find.byKey(const Key('smileid')));
        await tester.pumpAndSettle();

        expect(find.text(sentence), findsOneWidget);
        expect(find.text('Welcome back.'), findsOneWidget);
        expect(store.token, isNull);
        expect(api.lastVerifier, isNull);
      });
    }

    testWidgets('a 422 from the ticket exchange shows the server message', (
      tester,
    ) async {
      final api = FakeApi();
      final store = MemorySessionStore();
      await pumpApp(tester, api, store);
      api.failNext = const ApiException(
        422,
        'This sign-in has expired. Please sign in again.',
        errors: {
          'ticket': ['This sign-in has expired. Please sign in again.'],
        },
      );

      await tester.tap(find.byKey(const Key('smileid')));
      await tester.pumpAndSettle();

      expect(
        find.text('This sign-in has expired. Please sign in again.'),
        findsOneWidget,
      );
      expect(store.token, isNull);
    });

    testWidgets('a ticket made for another verifier is refused', (
      tester,
    ) async {
      final api = FakeApi();
      final store = MemorySessionStore();
      await pumpApp(
        tester,
        api,
        store,
        browser: FakeBrowserSignIn(api)
          ..ticketChallenge = challengeFor(newVerifier()),
      );

      await tester.tap(find.byKey(const Key('smileid')));
      await tester.pumpAndSettle();

      expect(
        find.text('This sign-in has expired. Please sign in again.'),
        findsOneWidget,
      );
      expect(find.text('Patients'), findsNothing);
      expect(store.token, isNull);
    });

    testWidgets('the web preview says it works in the phone app', (
      tester,
    ) async {
      await pumpApp(tester, FakeApi(), MemorySessionStore(), webPreview: true);

      await tester.tap(find.byKey(const Key('smileid')));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Sign in with SmileID works in the phone app. The web preview is for looking only.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('the server address counts for the SmileID button too', (
      tester,
    ) async {
      final api = FakeApi();
      final store = MemorySessionStore();
      final browser = FakeBrowserSignIn(api);
      await pumpApp(tester, api, store, browser: browser);

      await tester.ensureVisible(find.byKey(const Key('server-toggle')));
      await tester.tap(find.byKey(const Key('server-toggle')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('server')),
        'http://127.0.0.1:8030',
      );
      await tester.ensureVisible(find.byKey(const Key('smileid')));
      await tester.tap(find.byKey(const Key('smileid')));
      await tester.pumpAndSettle();

      expect(
        browser.opened.single.toString(),
        startsWith('http://127.0.0.1:8030/app/sign-in?'),
      );
      expect(store.serverUrl, 'http://127.0.0.1:8030');
      expect(find.text('Patients'), findsOneWidget);
    });
  });

  group('No password', () {
    testWidgets('the screen has the SmileID button and nothing to type', (
      tester,
    ) async {
      await pumpApp(tester, FakeApi(), MemorySessionStore());

      expect(find.byKey(const Key('smileid')), findsOneWidget);
      expect(find.text('Use your drShine password'), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(find.byKey(const Key('sign-in')), findsNothing);
    });

    testWidgets('a server that cannot be reached still shows the button', (
      tester,
    ) async {
      final api = FakeApi()..options = null;
      await pumpApp(tester, api, MemorySessionStore());

      expect(find.byKey(const Key('smileid')), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.byIcon(Icons.info_outline), findsNothing);
    });

    testWidgets('a server without SmileID says so, and offers no other way', (
      tester,
    ) async {
      final api = FakeApi()..options = const SignInOptions(smileId: false);
      await pumpApp(tester, api, MemorySessionStore());

      expect(
        find.text("Sign in with SmileID isn't ready on this server yet."),
        findsOneWidget,
      );
      expect(find.byKey(const Key('smileid')), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
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
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(api.baseUrl, 'http://127.0.0.1:8030');
      expect(store.serverUrl, 'http://127.0.0.1:8030');
    });
  });

  group('A session', () {
    testWidgets('a saved token goes straight to Patients', (tester) async {
      final store = MemorySessionStore(token: 'saved');
      await pumpApp(tester, FakeApi(), store);
      expect(find.text('Patients'), findsOneWidget);
    });

    testWidgets('a saved token the server refuses says why, once', (
      tester,
    ) async {
      const sentence = 'Your SmileID session has ended. Please sign in again.';
      final api = FakeApi()..failNext = const ApiException(401, sentence);
      final store = MemorySessionStore(token: 'saved');
      final browser = FakeBrowserSignIn(api)..closes = true;
      await pumpApp(tester, api, store, browser: browser);

      expect(find.text('Welcome back.'), findsOneWidget);
      expect(find.text(sentence), findsOneWidget);
      expect(store.token, isNull);

      await tester.tap(find.byKey(const Key('smileid')));
      await tester.pumpAndSettle();
      expect(find.text(sentence), findsNothing);
    });

    testWidgets(
      'a session the server ends while a patient is open closes that screen too',
      (tester) async {
        const sentence =
            'Your SmileID session has ended. Please sign in again.';
        final state = await pumpApp(
          tester,
          FakeApi(),
          MemorySessionStore(token: 'saved'),
        );
        tester
            .state<NavigatorState>(find.byType(Navigator))
            .push(
              MaterialPageRoute<void>(
                builder: (_) => const Scaffold(body: Text('A patient')),
              ),
            );
        await tester.pumpAndSettle();
        expect(find.text('A patient'), findsOneWidget);

        await state.sessionExpired(sentence);
        await tester.pumpAndSettle();

        expect(find.text('A patient'), findsNothing);
        expect(find.text('Welcome back.'), findsOneWidget);
        expect(find.text(sentence), findsOneWidget);
      },
    );

    testWidgets(
      'a session the server ends falls back to sign-in with its reason',
      (tester) async {
        const sentence = 'Sign in again with SmileID.';
        final store = MemorySessionStore(token: 'saved');
        final state = await pumpApp(tester, FakeApi(), store);
        expect(find.text('Patients'), findsOneWidget);

        await state.sessionExpired(sentence);
        await tester.pumpAndSettle();

        expect(find.text('Welcome back.'), findsOneWidget);
        expect(find.text(sentence), findsOneWidget);
        expect(store.token, isNull);
        expect(state.takeSignInNotice(), isNull);
      },
    );
  });
}
