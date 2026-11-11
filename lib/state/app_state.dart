import 'dart:async';

import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../auth/browser_sign_in.dart';
import 'session_store.dart';

enum SessionStatus { starting, signedOut, signedIn }

/// The signed-in session: server, token and user. One per app.
class AppState extends ChangeNotifier {
  AppState({required this.api, required this.store, this.browser});

  final ApiClient api;
  final SessionStore store;

  /// The system sign-in sheet; null in the web preview, which has none.
  final BrowserSignIn? browser;

  SessionStatus status = SessionStatus.starting;
  User? user;
  String? lastEmail;

  /// Whether the server has Sign in with SmileID. Null while loading, or when
  /// the server can't be reached.
  SignInOptions? signInOptions;

  /// Why the app is back on sign-in (the server's `401` message), until shown.
  String? _signInNotice;
  int _optionsRequest = 0;

  String get serverUrl => api.baseUrl;

  /// True only when the server answered that it has no Sign in with SmileID.
  bool get smileIdMissing => signInOptions?.smileId == false;

  /// The server's reason for the last sign-out, once.
  String? takeSignInNotice() {
    final notice = _signInNotice;
    _signInNotice = null;
    return notice;
  }

  /// Restores the saved server and token, and checks the token with `GET /me`.
  Future<void> start() async {
    final savedServer = await store.readServerUrl();
    if (savedServer != null && savedServer.isNotEmpty) {
      api.baseUrl = savedServer;
    }
    lastEmail = await store.readLastEmail();
    final token = await store.readToken();
    if (token == null || token.isEmpty) {
      _signedOut();
      return;
    }
    api.token = token;
    try {
      user = await api.me();
      _set(SessionStatus.signedIn);
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        _signInNotice = error.message;
        await _forget();
      }
      // Offline at launch: keep the token and let the user retry from sign-in.
      _signedOut();
    }
  }

  Future<void> setServer(String url) async {
    api.baseUrl = url;
    await store.writeServerUrl(api.baseUrl);
    notifyListeners();
    if (status == SessionStatus.signedOut) {
      unawaited(loadSignInOptions());
    }
  }

  /// Asks the server whether it has Sign in with SmileID. The last answer stays
  /// until the new one is in; a server that can't be reached clears it.
  Future<void> loadSignInOptions() async {
    final request = ++_optionsRequest;
    SignInOptions? options;
    try {
      options = await api.signInOptions();
    } on ApiException {
      options = null;
    }
    if (request != _optionsRequest) {
      return;
    }
    signInOptions = options;
    notifyListeners();
  }

  /// Signs in with SmileID in the system sheet. Closing the sheet does nothing;
  /// a refusal throws a [SignInException] with the sentence to show.
  ///
  /// [another] first signs the browser out of SmileID, to pick a different one.
  Future<void> signInWithSmileId({bool another = false}) async {
    final sheet = browser;
    if (sheet == null) {
      throw const SignInException(webPreviewSentence);
    }
    final verifier = newVerifier();
    final device = deviceName();
    final back = await sheet.open(
      api.smileIdStartUrl(
        challenge: challengeFor(verifier),
        device: device,
        email: another ? null : lastEmail,
        another: another,
      ),
    );
    if (back == null) {
      return;
    }
    final ticket = back.queryParameters['ticket'] ?? '';
    if (ticket.isEmpty) {
      throw SignInException(
        smileIdErrorSentence(back.queryParameters['error']),
      );
    }
    final result = await api.loginWithSmileId(
      ticket: ticket,
      verifier: verifier,
      device: device,
    );
    final email = result.user?.email ?? '';
    if (email.isNotEmpty) {
      lastEmail = email;
      await store.writeLastEmail(email);
    }
    await _signedIn(result);
  }

  Future<void> _signedIn(LoginResult result) async {
    api.token = result.token;
    await store.writeToken(result.token);
    user = result.user;
    _signInNotice = null;
    _set(SessionStatus.signedIn);
  }

  /// Signs out here and on the server. [notice] is a reason for the sign-in
  /// screen, when it was the app that signed the user out.
  Future<void> signOut({String? notice}) async {
    try {
      await api.logout();
    } on ApiException {
      // Signed out on this phone either way.
    }
    await _forget();
    _signInNotice = notice;
    _signedOut();
  }

  /// The server said the token is no longer valid; [message] is its reason.
  Future<void> sessionExpired([String? message]) async {
    if (status != SessionStatus.signedIn) {
      return;
    }
    // Requests run side by side: only the first `401` gets here.
    status = SessionStatus.signedOut;
    if (message != null && message.isNotEmpty) {
      _signInNotice = message;
    }
    await _forget();
    _signedOut();
  }

  Future<void> _forget() async {
    api.token = null;
    user = null;
    await store.writeToken(null);
  }

  void _signedOut() {
    _set(SessionStatus.signedOut);
    unawaited(loadSignInOptions());
  }

  void _set(SessionStatus value) {
    status = value;
    notifyListeners();
  }
}
