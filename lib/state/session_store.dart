import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where the app keeps the sign-in between launches.
abstract class SessionStore {
  Future<String?> readToken();
  Future<void> writeToken(String? token);
  Future<String?> readServerUrl();
  Future<void> writeServerUrl(String url);
  Future<String?> readLastEmail();
  Future<void> writeLastEmail(String email);

  /// When the user last proved who they are on this phone: a sign-in or an
  /// unlock. A time only; the app lock's morning rule reads it.
  Future<DateTime?> readLastUnlock();
  Future<void> writeLastUnlock(DateTime? at);
}

/// The token in the platform keychain / keystore; the server address, last
/// email and last unlock time (not secret) in shared preferences.
class DeviceSessionStore implements SessionStore {
  DeviceSessionStore({FlutterSecureStorage? secure})
    : _secure = secure ?? const FlutterSecureStorage();

  final FlutterSecureStorage _secure;
  static const _tokenKey = 'drshine.token';
  static const _serverKey = 'drshine.server';
  static const _emailKey = 'drshine.email';
  static const _unlockKey = 'drshine.unlocked_at';

  @override
  Future<String?> readToken() async {
    try {
      return await _secure.read(key: _tokenKey);
    } on Object {
      return null;
    }
  }

  @override
  Future<void> writeToken(String? token) async {
    try {
      if (token == null) {
        await _secure.delete(key: _tokenKey);
      } else {
        await _secure.write(key: _tokenKey, value: token);
      }
    } on Object {
      // The keychain can be unavailable (e.g. a locked device); the session
      // still works for this launch.
    }
  }

  @override
  Future<String?> readServerUrl() async =>
      (await SharedPreferences.getInstance()).getString(_serverKey);

  @override
  Future<void> writeServerUrl(String url) async =>
      (await SharedPreferences.getInstance()).setString(_serverKey, url);

  @override
  Future<String?> readLastEmail() async =>
      (await SharedPreferences.getInstance()).getString(_emailKey);

  @override
  Future<void> writeLastEmail(String email) async =>
      (await SharedPreferences.getInstance()).setString(_emailKey, email);

  @override
  Future<DateTime?> readLastUnlock() async => DateTime.tryParse(
    (await SharedPreferences.getInstance()).getString(_unlockKey) ?? '',
  );

  @override
  Future<void> writeLastUnlock(DateTime? at) async {
    final preferences = await SharedPreferences.getInstance();
    if (at == null) {
      await preferences.remove(_unlockKey);
    } else {
      await preferences.setString(_unlockKey, at.toUtc().toIso8601String());
    }
  }
}

/// An in-memory store, for tests.
class MemorySessionStore implements SessionStore {
  MemorySessionStore({
    this.token,
    this.serverUrl,
    this.lastEmail,
    this.lastUnlock,
  });

  String? token;
  String? serverUrl;
  String? lastEmail;
  DateTime? lastUnlock;

  @override
  Future<String?> readToken() async => token;

  @override
  Future<void> writeToken(String? value) async => token = value;

  @override
  Future<String?> readServerUrl() async => serverUrl;

  @override
  Future<void> writeServerUrl(String url) async => serverUrl = url;

  @override
  Future<String?> readLastEmail() async => lastEmail;

  @override
  Future<void> writeLastEmail(String email) async => lastEmail = email;

  @override
  Future<DateTime?> readLastUnlock() async => lastUnlock;

  @override
  Future<void> writeLastUnlock(DateTime? at) async => lastUnlock = at;
}
