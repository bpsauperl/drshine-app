import 'dart:async';

import 'package:flutter/foundation.dart';

import '../auth/device_unlock.dart';
import 'app_state.dart';

/// What the app shows in place of its content.
enum LockView {
  /// The app as usual.
  open,

  /// The wordmark only: the app is not in front, or still deciding.
  cover,

  /// The lock screen, until the phone's own unlock passes.
  locked,
}

/// Why a phone without a screen lock is back on sign-in in the morning.
const String noScreenLockSentence =
    'This phone has no Face ID, fingerprint or passcode, so drShine asks for your SmileID each morning.';

/// The app lock: a cover over the patient data on this phone, opened by the
/// phone's own unlock. The server's SmileID re-check is not part of it.
///
/// It asks when a saved session opens the app (always after the app was fully
/// closed), on the first return after 04:00 in Ljubljana, and on a return after
/// [awayLimit] in the background. A fresh sign-in counts as an unlock.
///
/// A phone with no screen lock can't be asked: it is signed out on the first
/// return after 04:00 instead, and otherwise opens.
class AppLock extends ChangeNotifier {
  AppLock({
    required this.state,
    required this.unlocker,
    DateTime Function()? clock,
    this.awayLimit = const Duration(minutes: 15),
  }) : _clock = clock ?? DateTime.now,
       _was = state.status {
    state.addListener(_onState);
  }

  final AppState state;
  final DeviceUnlock unlocker;

  /// How long the app may be in the background before it asks again.
  final Duration awayLimit;
  final DateTime Function() _clock;

  /// True while the system prompt is up.
  bool asking = false;

  LockView _view = LockView.open;
  SessionStatus _was;
  DateTime? _unlockedAt;
  DateTime? _leftAt;
  bool _hidden = false;
  bool _checking = false;

  /// What to show now. Only a signed-in app has anything to cover.
  LockView get view =>
      state.status == SessionStatus.signedIn ? _view : LockView.open;

  @override
  void dispose() {
    state.removeListener(_onState);
    super.dispose();
  }

  void _onState() {
    final was = _was;
    _was = state.status;
    if (was == _was) {
      return;
    }
    switch (_was) {
      case SessionStatus.starting:
        break;
      case SessionStatus.signedOut:
        _view = LockView.open;
        _leftAt = null;
        _unlockedAt = null;
        unawaited(state.store.writeLastUnlock(null));
        notifyListeners();
      case SessionStatus.signedIn:
        if (was == SessionStatus.starting) {
          // A saved session: covered at once, then asked.
          _view = LockView.cover;
          notifyListeners();
          unawaited(_restored());
        } else {
          // The user just signed in with SmileID.
          _markUnlocked();
          _leftAt = null;
          _view = LockView.open;
          notifyListeners();
        }
    }
  }

  Future<void> _restored() async {
    _unlockedAt = await state.store.readLastUnlock();
    await _check(coldStart: true);
  }

  /// Something is over the app, or it is on its way out. Covered here, while
  /// the app still draws, so the app switcher shows the wordmark.
  void appInactive() {
    if (state.status == SessionStatus.signedIn && _view == LockView.open) {
      _view = LockView.cover;
      notifyListeners();
    }
  }

  /// The app went to the background.
  void appHidden() {
    _hidden = true;
    if (state.status != SessionStatus.signedIn) {
      return;
    }
    _leftAt ??= _clock();
    if (_view == LockView.open) {
      _view = LockView.cover;
      notifyListeners();
    }
  }

  /// The app is in front again.
  Future<void> appResumed() async {
    _hidden = false;
    if (state.status != SessionStatus.signedIn || _view != LockView.cover) {
      // A lock screen that is already up waits for the Unlock button.
      return;
    }
    await _check(coldStart: false);
  }

  /// Decides between opening, asking and (with no screen lock) signing out.
  Future<void> _check({required bool coldStart}) async {
    if (_checking) {
      return;
    }
    _checking = true;
    try {
      final now = _clock();
      final leftAt = _leftAt;
      final away = leftAt != null && now.difference(leftAt) >= awayLimit;
      final newDay = _isNewDay(now);
      if (!coldStart && !newDay && !away) {
        _open();
        return;
      }
      final hasScreenLock = await unlocker.hasScreenLock();
      if (state.status != SessionStatus.signedIn) {
        return;
      }
      if (!hasScreenLock) {
        await _withoutScreenLock(newDay: newDay);
        return;
      }
      _view = LockView.locked;
      notifyListeners();
    } finally {
      _checking = false;
    }
    await unlock();
  }

  /// Shows the phone's prompt. The lock screen's Unlock button calls it again.
  Future<void> unlock() async {
    if (asking ||
        _view != LockView.locked ||
        state.status != SessionStatus.signedIn) {
      return;
    }
    asking = true;
    notifyListeners();
    final result = await unlocker.ask();
    asking = false;
    if (state.status != SessionStatus.signedIn) {
      notifyListeners();
      return;
    }
    switch (result) {
      case UnlockResult.unlocked:
        _markUnlocked();
        _open();
      case UnlockResult.notUnlocked:
        notifyListeners();
      case UnlockResult.noScreenLock:
        await _withoutScreenLock(newDay: _isNewDay(_clock()));
    }
  }

  /// The rule for a phone that has nothing to ask.
  Future<void> _withoutScreenLock({required bool newDay}) async {
    if (newDay) {
      await state.signOut(notice: noScreenLockSentence);
    } else {
      _open();
    }
  }

  bool _isNewDay(DateTime now) {
    final unlockedAt = _unlockedAt;
    return unlockedAt == null || unlockedAt.isBefore(ljubljanaDayStart(now));
  }

  void _markUnlocked() {
    final now = _clock();
    _unlockedAt = now;
    unawaited(state.store.writeLastUnlock(now));
  }

  void _open() {
    if (_hidden) {
      // Still in the background: stay covered, and decide again on return.
      _view = LockView.cover;
    } else {
      _view = LockView.open;
      _leftAt = null;
    }
    notifyListeners();
  }
}

/// The latest 04:00 in Ljubljana at or before [now], as a UTC time.
DateTime ljubljanaDayStart(DateTime now) {
  final utc = now.toUtc();
  // The Ljubljana wall clock, held in a UTC-valued DateTime.
  final wall = utc.add(ljubljanaOffset(utc));
  var four = DateTime.utc(wall.year, wall.month, wall.day, 4);
  if (wall.isBefore(four)) {
    four = DateTime.utc(wall.year, wall.month, wall.day - 1, 4);
  }
  // The clocks change at 02:00 or 03:00 there, so 04:00 happens once a day.
  final summer = four.subtract(const Duration(hours: 2));
  return ljubljanaOffset(summer) == const Duration(hours: 2)
      ? summer
      : four.subtract(const Duration(hours: 1));
}

/// Ljubljana's offset from UTC at [utc]: two hours in summer time (from the
/// last Sunday of March to the last Sunday of October, changing at 01:00 UTC),
/// one hour otherwise.
Duration ljubljanaOffset(DateTime utc) {
  final start = _lastSunday(utc.year, DateTime.march);
  final end = _lastSunday(utc.year, DateTime.october);
  final summer = !utc.isBefore(start) && utc.isBefore(end);
  return Duration(hours: summer ? 2 : 1);
}

/// 01:00 UTC on the last Sunday of [month].
DateTime _lastSunday(int year, int month) {
  final lastDay = DateTime.utc(year, month + 1, 0);
  return DateTime.utc(year, month, lastDay.day - lastDay.weekday % 7, 1);
}
