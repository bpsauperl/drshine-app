import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import 'session_store.dart';

enum SessionStatus { starting, signedOut, signedIn }

/// The signed-in session: server, token and user. One per app.
class AppState extends ChangeNotifier {
  AppState({required this.api, required this.store});

  final ApiClient api;
  final SessionStore store;

  SessionStatus status = SessionStatus.starting;
  User? user;
  String? lastEmail;

  /// Set while the server asks for the two-step code.
  String? twoFactorChallenge;

  String get serverUrl => api.baseUrl;

  /// Restores the saved server and token, and checks the token with `GET /me`.
  Future<void> start() async {
    final savedServer = await store.readServerUrl();
    if (savedServer != null && savedServer.isNotEmpty) {
      api.baseUrl = savedServer;
    }
    lastEmail = await store.readLastEmail();
    final token = await store.readToken();
    if (token == null || token.isEmpty) {
      _set(SessionStatus.signedOut);
      return;
    }
    api.token = token;
    try {
      user = await api.me();
      _set(SessionStatus.signedIn);
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        await _forget();
      }
      // Offline at launch: keep the token and let the user retry from sign-in.
      _set(SessionStatus.signedOut);
    }
  }

  Future<void> setServer(String url) async {
    api.baseUrl = url;
    await store.writeServerUrl(api.baseUrl);
    notifyListeners();
  }

  /// Signs in. Returns true when the server asks for the two-step code next.
  Future<bool> signIn({
    required String email,
    required String password,
    required String device,
  }) async {
    final result = await api.login(
      email: email.trim(),
      password: password,
      device: device,
    );
    lastEmail = email.trim();
    await store.writeLastEmail(lastEmail!);
    if (result.needsTwoFactor) {
      twoFactorChallenge = result.challenge;
      notifyListeners();
      return true;
    }
    await _signedIn(result);
    return false;
  }

  Future<void> confirmTwoFactor(String code) async {
    final challenge = twoFactorChallenge;
    if (challenge == null) {
      throw const ApiException(422, 'Sign in again to get a new code.');
    }
    await _signedIn(
      await api.loginTwoFactor(
        challenge: challenge,
        code: code.replaceAll(' ', ''),
      ),
    );
  }

  void cancelTwoFactor() {
    twoFactorChallenge = null;
    notifyListeners();
  }

  Future<void> _signedIn(LoginResult result) async {
    api.token = result.token;
    await store.writeToken(result.token);
    user = result.user;
    twoFactorChallenge = null;
    _set(SessionStatus.signedIn);
  }

  Future<void> signOut() async {
    try {
      await api.logout();
    } on ApiException {
      // Signed out on this phone either way.
    }
    await _forget();
    _set(SessionStatus.signedOut);
  }

  /// The server said the token is no longer valid.
  Future<void> sessionExpired() async {
    if (status != SessionStatus.signedIn) {
      return;
    }
    await _forget();
    _set(SessionStatus.signedOut);
  }

  Future<void> _forget() async {
    api.token = null;
    user = null;
    await store.writeToken(null);
  }

  void _set(SessionStatus value) {
    status = value;
    notifyListeners();
  }
}
