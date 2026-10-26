import 'package:flutter/material.dart';

import 'screens/patients_screen.dart';
import 'screens/sign_in_screen.dart';
import 'state/app_state.dart';
import 'theme.dart';
import 'widgets/common.dart';

/// The drShine app: sign-in until there is a session, then Patients.
class DrShineApp extends StatelessWidget {
  const DrShineApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: MaterialApp(
        title: 'drShine',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        themeMode: ThemeMode.system,
        home: ListenableBuilder(
          listenable: state,
          builder: (context, _) => switch (state.status) {
            SessionStatus.starting => const _Splash(),
            SessionStatus.signedOut => const SignInScreen(),
            SessionStatus.signedIn => const PatientsScreen(key: ValueKey('patients')),
          },
        ),
      ),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Wordmark(size: 40)));
}
