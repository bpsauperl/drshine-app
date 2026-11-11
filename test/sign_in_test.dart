import 'package:drshine/api/api_client.dart';
import 'package:drshine/auth/browser_sign_in.dart';
import 'package:drshine/state/session_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';

const _passwordsOn = SignInOptions(smileId: true, password: true);

/// Opens the password form behind "Use your drShine password".
Future<void> openPasswordForm(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('password-toggle')));
  await tester.pumpAndSettle();
}

Future<void> tapSignIn(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('sign-in')));
  await tester.tap(find.byKey(const Key('sign-in')));
  await tester.pumpAndSettle();
}

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

  group('The drShine password', () {
    testWidgets('is offered only when the server takes passwords', (
      tester,
    ) async {
      final api = FakeApi();
      await pumpApp(tester, api, MemorySessionStore());

      expect(find.byKey(const Key('smileid')), findsOneWidget);
      expect(find.byKey(const Key('password-toggle')), findsNothing);
      expect(find.byKey(const Key('email')), findsNothing);
      expect(find.byKey(const Key('password')), findsNothing);
      expect(find.byKey(const Key('sign-in')), findsNothing);
    });

    testWidgets('is hidden while the server cannot be reached', (tester) async {
      final api = FakeApi()..options = null;
      await pumpApp(tester, api, MemorySessionStore());

      expect(find.byKey(const Key('smileid')), findsOneWidget);
      expect(find.byKey(const Key('password-toggle')), findsNothing);
      expect(find.byKey(const Key('password')), findsNothing);
    });

    testWidgets('opens behind its link and signs in, then shows Patients', (
      tester,
    ) async {
      final api = FakeApi()..options = _passwordsOn;
      final store = MemorySessionStore();
      await pumpApp(tester, api, store);

      expect(find.text('Use your drShine password'), findsOneWidget);
      expect(find.byKey(const Key('email')), findsNothing);
      await openPasswordForm(tester);

      await tapSignIn(tester);
      expect(find.text('Enter your email and password.'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('email')),
        'doctor@drshine.test',
      );
      await tester.enterText(find.byKey(const Key('password')), 'example');
      await tapSignIn(tester);

      expect(find.text('Patients'), findsOneWidget);
      expect(find.text('Test Patient'), findsOneWidget);
      expect(store.token, 'token-1');
      expect(store.lastEmail, 'doctor@drshine.test');
    });

    testWidgets('asks for the 6-digit code when two-step is on', (
      tester,
    ) async {
      final api = FakeApi()
        ..options = _passwordsOn
        ..twoFactor = true;
      final store = MemorySessionStore();
      await pumpApp(tester, api, store);
      await openPasswordForm(tester);

      await tester.enterText(
        find.byKey(const Key('email')),
        'doctor@drshine.test',
      );
      await tester.enterText(find.byKey(const Key('password')), 'example');
      await tapSignIn(tester);

      expect(find.text('One more step.'), findsOneWidget);
      expect(find.byKey(const Key('password')), findsNothing);
      expect(find.byKey(const Key('smileid')), findsNothing);
      expect(store.token, isNull);

      await tester.enterText(find.byKey(const Key('code')), '123456');
      await tapSignIn(tester);

      expect(api.lastCode, '123456');
      expect(find.text('Patients'), findsOneWidget);
      expect(store.token, 'token-2');
    });

    testWidgets('a clinic that signs in with SmileID is told so', (
      tester,
    ) async {
      final api = FakeApi()..options = _passwordsOn;
      final store = MemorySessionStore();
      await pumpApp(tester, api, store);
      await openPasswordForm(tester);
      api.failNext = const ApiException(
        422,
        'Your clinic signs in with SmileID.',
        errors: {
          'email': ['Your clinic signs in with SmileID.'],
        },
      );

      await tester.enterText(
        find.byKey(const Key('email')),
        'doctor@drshine.test',
      );
      await tester.enterText(find.byKey(const Key('password')), 'example');
      await tapSignIn(tester);

      expect(find.text('Your clinic signs in with SmileID.'), findsOneWidget);
      expect(store.token, isNull);
    });

    testWidgets('starts open on a server that has no SmileID', (tester) async {
      final api = FakeApi()
        ..options = const SignInOptions(smileId: false, password: true);
      await pumpApp(tester, api, MemorySessionStore());

      expect(find.byKey(const Key('email')), findsOneWidget);
      expect(find.byKey(const Key('password')), findsOneWidget);
    });

    testWidgets('the server address can be changed and is remembered', (
      tester,
    ) async {
      final api = FakeApi()..options = _passwordsOn;
      final store = MemorySessionStore();
      await pumpApp(tester, api, store);
      await openPasswordForm(tester);

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
      await tapSignIn(tester);

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
