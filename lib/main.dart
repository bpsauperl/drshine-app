import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api/http_api_client.dart';
import 'app.dart';
import 'auth/browser_sign_in.dart';
import 'state/app_state.dart';
import 'state/session_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Portrait only on phones; tablets may rotate.
  final view = WidgetsBinding.instance.platformDispatcher.views.first;
  final shortestSide = view.physicalSize.shortestSide / view.devicePixelRatio;
  if (shortestSide < 600) {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  final api = HttpApiClient();
  final state = AppState(
    api: api,
    store: DeviceSessionStore(),
    // The web preview has no sign-in sheet.
    browser: kIsWeb ? null : const SystemBrowserSignIn(),
  );
  api.onUnauthorized = state.sessionExpired;
  runApp(DrShineApp(state: state));
  await state.start();
}
