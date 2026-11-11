import 'package:flutter/material.dart';

import 'screens/patients_screen.dart';
import 'screens/sign_in_screen.dart';
import 'state/app_state.dart';
import 'theme.dart';
import 'widgets/common.dart';

/// The drShine app: sign-in until there is a session, then Patients.
class DrShineApp extends StatefulWidget {
  const DrShineApp({super.key, required this.state});

  final AppState state;

  @override
  State<DrShineApp> createState() => _DrShineAppState();
}

class _DrShineAppState extends State<DrShineApp> {
  final _navigator = GlobalKey<NavigatorState>();
  late SessionStatus _status = widget.state.status;

  @override
  void initState() {
    super.initState();
    widget.state.addListener(_onState);
  }

  @override
  void dispose() {
    widget.state.removeListener(_onState);
    super.dispose();
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
    return AppScope(
      state: state,
      child: MaterialApp(
        title: 'drShine',
        navigatorKey: _navigator,
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        themeMode: ThemeMode.system,
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

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Wordmark(size: 40)));
}
