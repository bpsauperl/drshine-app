# drShine app

The clinics' app for **Shine clear aligners** (SmileLabs, Slovenia). A dentist or an assistant starts an Aligners order on the phone, takes the patient photos with the guided camera, and completes the order up to Submit.

- iOS and Android. The web build is for previewing only: the camera doesn't run there.
- Bundle id / application id: `si.smilelabs.drshine`. Display name: **drShine**. Version `1.0.0+1`.
- The server is drShine (Laravel). The app follows the [API contract v1, section A](docs/app-api-contract.md) (`/api/app/v1`).

## What's in it

| Screen | What it does |
| --- | --- |
| Sign in | Email and password, then the 6-digit two-step code (or a recovery code) when the server asks for it. "Server" changes the base URL. |
| Patients | Search by name or ID, the list (name, status, ID), and "New patient". |
| Patient | Summary and orders. "New Aligners order", or continue a draft. |
| Order builder | A progress strip: **Plan** (only when `plan_choice.asks`), **Photos**, **Scans**, **RX**, **Submit**. |
| Guided camera | A full-screen preview with a faded outline of what to capture, an instruction, shutter, flash, front/back switch, Use photo / Retake, and arrows to move through the slots. |
| Settings | Signed-in user, clinic, server, sign out. |

```
lib/
  main.dart                  start-up, portrait lock on phones
  app.dart                   MaterialApp, light and dark themes, sign-in or Patients
  theme.dart                 palette (indigo #5364a3 on #f4f6fa), shapes, type
  api/
    api_client.dart          ApiClient interface + ApiException (fakeable in tests)
    http_api_client.dart     the HTTP implementation (package:http)
    models.dart              JSON models for contract v1
  state/
    app_state.dart           session: server, token, user (ChangeNotifier)
    session_store.dart       token in flutter_secure_storage, server in shared_preferences
    order_builder.dart       the builder's logic: steps, completion, missing, attestations, uploads
  screens/
    sign_in_screen.dart, patients_screen.dart, new_patient_sheet.dart,
    patient_screen.dart, settings_screen.dart
    order/                   the builder and its steps (plan, photos, scans, rx, submit, done)
    camera/
      blueprint.dart         the outline drawings (CustomPainter), one per photo slot
      guided_camera_screen.dart
  widgets/common.dart        wordmark, tiles, pills, notices
  util/format.dart           euros (€1.150) and dates
test/                        logic, JSON parsing, sign-in and camera-overlay tests
docs/app-api-contract.md     the API contract the app codes against
```

## Run it

Use Flutter stable (3.47 or newer).

```sh
flutter pub get
flutter analyze
flutter test
flutter run                 # on a connected phone, or a simulator / emulator
flutter run -d chrome       # web preview (no camera)
```

The default server is `https://drshine-dev-h4s1yo.laravel.cloud` (DEV, made-up example data). For a local drShine, open **Server** on the sign-in screen and enter `http://127.0.0.1:8030` (from an Android emulator: `http://10.0.2.2:8030`).

To preview the web build:

```sh
flutter build web
cd build/web && python3 -m http.server 8077     # then open http://127.0.0.1:8077
```

## The API

See [docs/app-api-contract.md](docs/app-api-contract.md), section A. The app codes strictly against it:

- `POST /login` (and `/login/two-factor`), `POST /logout`, `GET /me`;
- `GET/POST /patients`, `GET /patients/{id}`;
- `POST /orders`, `GET /orders/{id}`, `PUT /orders/{id}/plan`, `POST /orders/{id}/files`, `GET/DELETE /orders/{id}/files/{file}`, `PUT /orders/{id}/rx`, `GET /orders/{id}/scans`, `POST /orders/{id}/scans/{scan}/import`, `POST /orders/{id}/submit`.

All HTTP lives in `lib/api/`. A `401` signs the user out; `403`, `409`, `422` and `429` show the server's `message`.

How the app reads the contract:
- Photo outlines are chosen by **slot** first (it tells left from right), with the `guide` key as the fallback for new slots.
- The **Scans** step covers the server's `impressions` and `cbct` steps. Uploading `.stl` files is left to drshine web.
- Photos are uploaded as JPEG; a new photo replaces whatever was in the slot.
- Patient countries are the names drShine accepts (Slovenia, Croatia, Austria, …).

## Build and sign for the stores

### App Store (iOS)

You need a Mac with Xcode, an Apple Developer Program membership, and access to SmileLabs' team.

1. In App Store Connect, create the app with bundle id `si.smilelabs.drshine` and the name **drShine**.
2. `open ios/Runner.xcworkspace`. Under **Runner → Signing & Capabilities**, choose the SmileLabs team and keep "Automatically manage signing" on. The bundle id is already `si.smilelabs.drshine`.
3. Build: `flutter build ipa --release`. Upload `build/ios/ipa/*.ipa` with Transporter, or open `build/ios/archive/Runner.xcarchive` in Xcode → Distribute App.
4. The camera text is in `ios/Runner/Info.plist` (`NSCameraUsageDescription`: "drShine uses the camera to take your patients' treatment photos."). iPhone is portrait only; iPad may rotate.

### Google Play (Android)

1. Make an upload key once and keep it safe (never commit it):
   ```sh
   keytool -genkey -v -keystore ~/drshine-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
2. Create `android/key.properties` (already in `android/.gitignore`):
   ```properties
   storePassword=…
   keyPassword=…
   keyAlias=upload
   storeFile=/Users/you/drshine-upload.jks
   ```
   `android/app/build.gradle.kts` signs release builds with it when the file exists, and with the debug key otherwise.
3. Build: `flutter build appbundle --release` → `build/app/outputs/bundle/release/app-release.aab`.
4. In Play Console, create the app (package `si.smilelabs.drshine`), turn on Play App Signing, and upload the `.aab`.

The Android build declares the camera permission, uses `minSdk` 23 or higher, and is labelled **drShine**. Phones are locked to portrait at start-up.

## What's left

- **App icons:** the launcher icons are still Flutter's defaults. Replace them in `ios/Runner/Assets.xcassets/AppIcon.appiconset`, `android/app/src/main/res/mipmap-*` and `web/icons`.
- **Store screenshots** for iPhone (and iPad, if offered) and Android phones.
- **Privacy policy URL** for both stores, plus the App Store privacy answers and the Play data-safety form (the app handles patient photos and health data).
- **Choose from library:** not in this version. The `camera` package can't pick from the gallery, and none of the allowed packages can.
- **A first run on real devices:** camera permission, flash, front/back switching and uploads haven't been tried on hardware yet (the app was built and tested without Xcode or the Android SDK).

The sample data in the tests is made up. Never use real patient names or photos as sample data.
