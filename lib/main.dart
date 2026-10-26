import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api/http_api_client.dart';
import 'app.dart';
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
  final state = AppState(api: api, store: DeviceSessionStore());
  api.onUnauthorized = state.sessionExpired;
  runApp(DrShineApp(state: state));
  await state.start();
}
