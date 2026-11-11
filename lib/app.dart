import 'package:flutter/material.dart';

import 'screens/lock_screen.dart';
import 'screens/patients_screen.dart';
import 'screens/sign_in_screen.dart';
import 'state/app_lock.dart';
import 'state/app_state.dart';
import 'theme.dart';
import 'widgets/common.dart';

/// The drShine app: sign-in until there is a session, then Patients, behind
/// the app lock when there is one.
class DrShineApp extends StatefulWidget {
  const DrShineApp({super.key, required this.state, this.lock});

  final AppState state;

  /// The app lock; null in the web preview, which has no phone to ask.
  final AppLock? lock;

  @override
  State<DrShineApp> createState() => _DrShineAppState();
}

class _DrShineAppState extends State<DrShineApp> with WidgetsBindingObserver {
  final _navigator = GlobalKey<NavigatorState>();
  late SessionStatus _status = widget.state.status;

  @override
  void initState() {
    super.initState();
    widget.state.addListener(_onState);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.state.removeListener(_onState);
    super.dispose();
  }

  /// The lock hears when the app leaves the screen and when it is back. A
  /// system prompt over the app (Face ID, a permission) only makes it inactive,
  /// which covers the app but does not count as time away.
  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    switch (lifecycle) {
      case AppLifecycleState.inactive:
        widget.lock?.appInactive();
      case AppLifecycleState.hidden || AppLifecycleState.paused:
        widget.lock?.appHidden();
      case AppLifecycleState.resumed:
        widget.lock?.appResumed();
      case AppLifecycleState.detached:
        break;
    }
  }

  /// A session that ends while another screen is open (a patient, an order)
  /// closes those screens, so the sign-in screen is what the user sees.
  void _onState() {
    final was = _status;
    _status = widget.state.status;
    if (was == SessionStatus.signedIn && _status == SessionStatus.signedOut) {
      _navigator.currentState?.popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final lock = widget.lock;
    return AppScope(
      state: state,
      child: MaterialApp(
        title: 'drShine',
        navigatorKey: _navigator,
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        themeMode: ThemeMode.system,
        // Above the navigator, so the lock covers every open screen and sheet.
        builder: (context, child) => lock == null
            ? child!
            : ListenableBuilder(
                listenable: Listenable.merge([state, lock]),
                builder: (context, _) => _Locked(lock: lock, child: child!),
              ),
        home: ListenableBuilder(
          listenable: state,
          builder: (context, _) => switch (state.status) {
            SessionStatus.starting => const _Splash(),
            SessionStatus.signedOut => const SignInScreen(),
            SessionStatus.signedIn => const PatientsScreen(
              key: ValueKey('patients'),
            ),
          },
        ),
      ),
    );
  }
}

/// The app, or what covers it: the lock screen, or the wordmark while the app
/// is in the background. The covered screens stay as they were underneath.
class _Locked extends StatelessWidget {
  const _Locked({required this.lock, required this.child});

  final AppLock lock;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final view = lock.view;
    final covered = view != LockView.open;
    return Stack(
      fit: StackFit.expand,
      children: [
        ExcludeFocus(
          excluding: covered,
          child: Offstage(offstage: covered, child: child),
        ),
        if (view == LockView.cover) const _Splash(),
        if (view == LockView.locked) LockScreen(lock: lock),
      ],
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Wordmark(size: 40)));
}
