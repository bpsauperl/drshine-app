import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

/// The scheme the sign-in sheet comes back on: `si.smilelabs.drshine:/callback`.
const String signInCallbackScheme = 'si.smilelabs.drshine';

/// What the SmileID button says in the web preview, where there is no sheet.
const String webPreviewSentence =
    'Sign in with SmileID works in the phone app. The web preview is for looking only.';

/// A sign-in that did not go through, with the sentence to show.
class SignInException implements Exception {
  const SignInException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The system sign-in sheet. The real one is [SystemBrowserSignIn]; tests use a fake.
abstract class BrowserSignIn {
  /// Opens [url] and waits for the page to come back to the app.
  ///
  /// Returns the link the sheet ended on, or null when the user closed it.
  Future<Uri?> open(Uri url);
}

/// [BrowserSignIn] on the system sheet: ASWebAuthenticationSession on iPhone,
/// Custom Tabs on Android. Private (ephemeral), so nothing stays signed in there.
class SystemBrowserSignIn implements BrowserSignIn {
  const SystemBrowserSignIn();

  @override
  Future<Uri?> open(Uri url) async {
    try {
      final back = await FlutterWebAuth2.authenticate(
        url: url.toString(),
        callbackUrlScheme: signInCallbackScheme,
        options: const FlutterWebAuth2Options(preferEphemeral: true),
      );
      return Uri.tryParse(back);
    } on PlatformException catch (error) {
      if (error.code == 'CANCELED') {
        return null;
      }
      throw const SignInException(
        "The sign-in page couldn't be opened. Please try again.",
      );
    }
  }
}

/// The sentence for an `error` code the sheet came back with.
String smileIdErrorSentence(String? code) => switch (code) {
  'switched_off' => 'This SmileID is switched off.',
  'no_account' => "There is no drShine account for this SmileID. Your clinic's director can invite you.",
  'clinic_off' => "This clinic's account is switched off. Contact SmileLabs.",
  'not_ready' => "Sign in with SmileID isn't ready on this server yet.",
  _ => "Signing in with SmileID didn't finish. Please try again.",
};

/// A new secret for one sign-in: 32 random bytes as base64url without padding
/// (43 characters). It never leaves the phone until the ticket is exchanged.
String newVerifier([Random? random]) {
  final source = random ?? Random.secure();
  return _base64Url(List<int>.generate(32, (_) => source.nextInt(256)));
}

/// The challenge the server remembers: sha256 of [verifier], as base64url
/// without padding (43 characters).
String challengeFor(String verifier) =>
    _base64Url(sha256.convert(ascii.encode(verifier)).bytes);

String _base64Url(List<int> bytes) =>
    base64Url.encode(bytes).replaceAll('=', '');

/// The device name the server shows in the user's sessions.
String deviceName() {
  if (kIsWeb) {
    return 'drShine web preview';
  }
  return switch (defaultTargetPlatform) {
    TargetPlatform.iOS => 'drShine on iPhone',
    TargetPlatform.android => 'drShine on Android',
    _ => 'drShine app',
  };
}
