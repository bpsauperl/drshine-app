import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api/http_api_client.dart';
import 'app.dart';
import 'auth/browser_sign_in.dart';
import 'auth/device_unlock.dart';
import 'state/app_lock.dart';
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
  // The web preview has no phone to ask.
  final lock = kIsWeb
      ? null
      : AppLock(state: state, unlocker: SystemDeviceUnlock());
  runApp(DrShineApp(state: state, lock: lock));
  await state.start();
}
