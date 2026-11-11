import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// What the phone answered when the app asked it to unlock.
enum UnlockResult {
  /// Face ID, Touch ID, the fingerprint or the passcode passed.
  unlocked,

  /// Cancelled, failed or interrupted: the app stays locked.
  notUnlocked,

  /// The phone has no Face ID, fingerprint or passcode to ask.
  noScreenLock,
}

/// The phone's own unlock: Face ID, Touch ID, the Android fingerprint, with the
/// passcode behind them. The real one is [SystemDeviceUnlock]; tests use a fake.
abstract class DeviceUnlock {
  /// Whether this phone has anything to ask: biometrics or a passcode.
  Future<bool> hasScreenLock();

  /// Shows the system prompt and waits for the answer.
  Future<UnlockResult> ask();
}

/// [DeviceUnlock] on the system prompt (local_auth).
class SystemDeviceUnlock implements DeviceUnlock {
  SystemDeviceUnlock({LocalAuthentication? auth})
    : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<bool> hasScreenLock() async {
    try {
      return await _auth.isDeviceSupported();
    } on PlatformException {
      // The phone didn't say: ask, and let the prompt's answer tell.
      return true;
    }
  }

  @override
  Future<UnlockResult> ask() async {
    try {
      final passed = await _auth.authenticate(
        localizedReason: 'Unlock drShine to see your patients.',
        // A prompt the user leaves comes back with the app instead of failing.
        persistAcrossBackgrounding: true,
      );
      return passed ? UnlockResult.unlocked : UnlockResult.notUnlocked;
    } on LocalAuthException catch (error) {
      return error.code == LocalAuthExceptionCode.noCredentialsSet
          ? UnlockResult.noScreenLock
          : UnlockResult.notUnlocked;
    } on PlatformException {
      return UnlockResult.notUnlocked;
    }
  }
}
