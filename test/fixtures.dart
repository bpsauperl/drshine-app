import 'dart:typed_data';

import 'package:drshine/api/api_client.dart';
import 'package:drshine/app.dart';
import 'package:drshine/auth/browser_sign_in.dart';
import 'package:drshine/auth/device_unlock.dart';
import 'package:drshine/state/app_lock.dart';
import 'package:drshine/state/app_state.dart';
import 'package:drshine/state/session_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// Made-up example data only. Never real patients.
const List<(String, String, String, bool, String)> photoSlots = [
  ('frontal_smile', 'Frontal smile', 'Face photos', true, 'face-front'),
  ('frontal', 'Frontal', 'Face photos', true, 'face-front'),
  (
    'left_profile_smile',
    'Left profile smile',
    'Face photos',
    true,
    'face-left',
  ),
  ('left_profile', 'Left profile', 'Face photos', true, 'face-left'),
  (
    'right_profile_smile',
    'Right profile smile',
    'Face photos',
    true,
    'face-right',
  ),
  ('right_profile', 'Right profile', 'Face photos', true, 'face-right'),
  ('front_arches', 'Front arches', 'Intraoral photos', true, 'bite'),
  ('left_bite', 'Left bite', 'Intraoral photos', true, 'bite'),
  ('right_bite', 'Right bite', 'Intraoral photos', true, 'bite'),
  (
    'occlusal_upper',
    'Occlusal upper',
    'Intraoral photos',
    true,
    'occlusal-upper',
  ),
  (
    'occlusal_lower',
    'Occlusal lower',
    'Intraoral photos',
    true,
    'occlusal-lower',
  ),
  ('overjet', 'Overjet', 'Intraoral photos', true, 'overjet'),
  ('panoramic_xray', 'Panoramic X-ray', 'X-ray photos', false, 'xray'),
  (
    'lateral_cephalometric',
    'Lateral cephalometric',
    'X-ray photos',
    false,
    'xray',
  ),
  (
    'left_front_45_smile',
    'Left 45° smile',
    'Additional photos',
    false,
    'face-left45',
  ),
  ('left_front_45', 'Left 45°', 'Additional photos', false, 'face-left45'),
  (
    'right_front_45_smile',
    'Right 45° smile',
    'Additional photos',
    false,
    'face-right45',
  ),
  ('right_front_45', 'Right 45°', 'Additional photos', false, 'face-right45'),
];

Map<String, dynamic> userJson({bool canSend = true}) => {
  'id': 7,
  'name': 'Dr. Example Doctor',
  'email': 'doctor@drshine.test',
  'role': canSend ? 'doctor' : 'assistant',
  'role_label': canSend ? 'Doctor' : 'Assistant',
  'can_send': canSend,
  'clinic': {'id': 3, 'name': 'Example Dental Clinic'},
};

Map<String, dynamic> patientJson() => {
  'id': 'p-1',
  'code': 'AB12CD34',
  'name': 'Test Patient',
  'first_name': 'Test',
  'last_name': 'Patient',
  'birth_date': '2001-04-02',
  'status': 'new',
  'status_label': 'New',
  'doctor': {'id': 7, 'name': 'Dr. Example Doctor'},
  'clinic': {'id': 3, 'name': 'Example Dental Clinic'},
  'is_minor': false,
};

/// A draft Aligners order. [taken] photo slots have a file; scans and RX as given.
Map<String, dynamic> orderJson({
  bool asksPlan = true,
  String? planKind,
  String? audience,
  Set<String> taken = const {},
  bool scans = false,
  bool rx = false,
  bool canSend = true,
}) {
  final photos = [
    for (final (slot, label, group, required, guide) in photoSlots)
      {
        'slot': slot,
        'label': label,
        'group': group,
        'required': required,
        'guide': guide,
        'file': taken.contains(slot)
            ? {
                'id': 'f-$slot',
                'name': '$slot.jpg',
                'url': 'https://x.test/f-$slot',
              }
            : null,
      },
  ];
  final planChosen =
      planKind == 'flexible' || (planKind == 'complete' && audience != null);
  final missingPhotos = [
    for (final (slot, label, _, required, _) in photoSlots)
      if (required && !taken.contains(slot)) '$label photo is missing',
  ];
  final missing = <String, List<String>>{
    if (asksPlan)
      'plan': [if (!planChosen) 'Choose a Complete or a Flexible plan'],
    'photos': missingPhotos,
    'cbct': [],
    'impressions': scans
        ? []
        : ['Upper jaw scan is missing', 'Lower jaw scan is missing'],
    'rx': rx ? [] : ['Choose who plans the case', 'Choose the arches'],
    'submit': [],
  };
  final ready = missing.values.every((m) => m.isEmpty);
  final required = photoSlots.where((s) => s.$4).length;
  return {
    'id': 'o-1',
    'reference': 'O1A2B3C4',
    'type': 'aligner_series',
    'type_label': 'Aligners',
    'series': 1,
    'status': 'draft',
    'status_label': 'Draft',
    'draft': true,
    'can_send': canSend,
    'submitted_at': null,
    'steps': [
      if (asksPlan)
        {
          'key': 'plan',
          'label': 'Plan',
          'complete': planChosen,
          'status': planChosen ? 'Flexible' : 'Not chosen yet',
        },
      {
        'key': 'photos',
        'label': 'Photos',
        'complete': missingPhotos.isEmpty,
        'status': '${required - missingPhotos.length} of $required photos',
      },
      {
        'key': 'cbct',
        'label': 'CBCT',
        'complete': true,
        'status': 'Not needed',
      },
      {
        'key': 'impressions',
        'label': 'Impressions',
        'complete': scans,
        'status': scans ? 'Upper and lower' : 'No scans yet',
      },
      {
        'key': 'rx',
        'label': 'RX',
        'complete': rx,
        'status': rx ? 'Shine Planning · Dual' : 'Not started',
      },
      {
        'key': 'submit',
        'label': 'Submit',
        'complete': false,
        'status': ready ? 'Ready to send' : 'Steps to finish',
      },
    ],
    'plan_choice': {'asks': asksPlan, 'kind': planKind, 'audience': audience},
    'photos': photos,
    'scans': [
      {
        'slot': 'upper_scan',
        'label': 'Upper jaw',
        'file': scans ? {'id': 's-u', 'name': 'upper.stl', 'url': ''} : null,
      },
      {
        'slot': 'lower_scan',
        'label': 'Lower jaw',
        'file': scans ? {'id': 's-l', 'name': 'lower.stl', 'url': ''} : null,
      },
    ],
    'rx': {
      'planning_partner': rx ? 'shine_planning' : null,
      'arches': rx ? 'dual' : null,
      'concerns': rx ? ['crowding'] : [],
      'treatment_goal': null,
      'prescription': null,
    },
    'options': {
      'partners': [
        {
          'value': 'shine_planning',
          'label': 'Shine Planning',
          'description': 'The Shine clinical team plans the case.',
        },
        {
          'value': 'clear_forward',
          'label': 'ClearForward',
          'description': 'ClearForward plans the case for you.',
        },
      ],
      'arches': [
        {'value': 'dual', 'label': 'Both arches'},
        {'value': 'maxillary', 'label': 'Upper'},
        {'value': 'mandibular', 'label': 'Lower'},
      ],
      'concerns': [
        {'value': 'crowding', 'label': 'Crowding'},
        {'value': 'spacing', 'label': 'Spacing'},
      ],
    },
    'missing': missing,
    'ready': ready,
    'price_lines': [
      {'label': 'Treatment plan', 'detail': 'Flexible', 'amount_cents': 10000},
      {
        'label': 'Aligners',
        'detail': 'Priced when the plan is ready',
        'amount_cents': null,
      },
      {'label': 'Package', 'detail': null, 'amount_cents': 105000},
    ],
    'total_cents': 115000,
    'attestations': [
      {
        'id': 'P1',
        'title': 'Records are complete',
        'text': 'The photos and scans are current.',
      },
      {
        'id': 'P2',
        'title': 'Patient informed',
        'text': 'The patient knows the treatment.',
      },
      {
        'id': 'P3',
        'title': 'Clinical check',
        'text': 'Teeth and gums are healthy for aligners.',
      },
    ],
  };
}

Set<String> requiredSlots() => {
  for (final s in photoSlots)
    if (s.$4) s.$1,
};

/// A scriptable [ApiClient] for widget and logic tests.
class FakeApi implements ApiClient {
  FakeApi({Map<String, dynamic>? order}) : orderData = order ?? orderJson();

  @override
  String baseUrl = defaultServerUrl;

  @override
  String? token;

  Map<String, dynamic> orderData;
  List<String>? submitted;
  Rx? savedRx;
  final List<String> uploads = [];
  ApiException? failNext;
  bool userCanSend = true;

  /// The orders `patient()` returns.
  List<Map<String, dynamic>> patientOrders = [];

  /// What `signInOptions()` answers; null plays a server that can't be reached.
  SignInOptions? options = const SignInOptions(smileId: true);

  /// The tickets the fake sheet handed out, each with the challenge it was for.
  final Map<String, String> tickets = {};
  String? lastVerifier;

  void _maybeFail() {
    final f = failNext;
    if (f != null) {
      failNext = null;
      throw f;
    }
  }

  @override
  Future<SignInOptions> signInOptions() async =>
      options ?? (throw const ApiException(0, "Can't reach the server."));

  @override
  Uri smileIdStartUrl({
    required String challenge,
    required String device,
    String? email,
    bool another = false,
  }) => Uri.parse('$baseUrl/app/sign-in').replace(
    queryParameters: {
      'challenge': challenge,
      'device': device,
      'email': ?email,
      if (another) 'switch': '1',
    },
  );

  /// Like the server: a ticket works once, and only with the verifier whose
  /// challenge it was made for.
  @override
  Future<LoginResult> loginWithSmileId({
    required String ticket,
    required String verifier,
    required String device,
  }) async {
    lastVerifier = verifier;
    _maybeFail();
    if (tickets.remove(ticket) != challengeFor(verifier)) {
      const message = 'This sign-in has expired. Please sign in again.';
      throw const ApiException(
        422,
        message,
        errors: {
          'ticket': [message],
        },
      );
    }
    return LoginResult(
      token: 'token-smileid',
      user: User.fromJson(userJson(canSend: userCanSend)),
    );
  }

  @override
  Future<void> logout() async {}

  @override
  Future<User> me() async {
    _maybeFail();
    return User.fromJson(userJson(canSend: userCanSend));
  }

  @override
  Future<List<Patient>> patients({String query = ''}) async => [
    Patient.fromJson(patientJson()),
  ];

  @override
  Future<Patient> createPatient(NewPatient patient) async =>
      Patient.fromJson(patientJson());

  @override
  Future<PatientDetail> patient(String id) async => PatientDetail.fromJson({
    'patient': patientJson(),
    'orders': patientOrders,
  });

  @override
  Future<Order> createAlignersOrder(String patientId) async =>
      Order.fromJson(orderData);

  @override
  Future<Order> order(String id) async => Order.fromJson(orderData);

  @override
  Future<Order> choosePlan(
    String orderId, {
    required String kind,
    String? audience,
  }) async {
    orderData = {
      ...orderData,
      'plan_choice': {'asks': true, 'kind': kind, 'audience': audience},
    };
    return Order.fromJson(orderData);
  }

  @override
  Future<OrderFile> uploadFile(
    String orderId, {
    required String kind,
    required String slot,
    required Uint8List bytes,
    required String filename,
  }) async {
    _maybeFail();
    uploads.add(slot);
    return OrderFile(id: 'f-$slot', name: filename, url: '');
  }

  @override
  Future<void> deleteFile(String orderId, String fileId) async {}

  @override
  Future<Uint8List> fileBytes(String orderId, String fileId) async =>
      Uint8List(0);

  @override
  Future<Order> saveRx(String orderId, Rx rx) async {
    savedRx = rx;
    return Order.fromJson(orderData);
  }

  @override
  Future<ScanInbox> scans(String orderId) async =>
      const ScanInbox(connected: true, scans: []);

  @override
  Future<Order> importScan(String orderId, String scanId) async =>
      Order.fromJson(orderData);

  @override
  Future<Order> submit(String orderId, List<String> attest) async {
    _maybeFail();
    submitted = attest;
    return Order.fromJson({
      ...orderData,
      'draft': false,
      'status': 'received',
      'submitted_at': '2026-10-26T09:30:00+01:00',
    });
  }
}

/// The sign-in sheet, faked: it hands back a ticket for the link's challenge,
/// an error code, or nothing when the user closes it.
class FakeBrowserSignIn implements BrowserSignIn {
  FakeBrowserSignIn(this.api);

  final FakeApi api;

  /// Every link the app opened.
  final List<Uri> opened = [];

  /// The user closes the sheet.
  bool closes = false;

  /// The server sends the sheet back with this error code.
  String? error;

  /// The challenge the ticket is made for; the link's own when null.
  String? ticketChallenge;

  @override
  Future<Uri?> open(Uri url) async {
    opened.add(url);
    if (closes) {
      return null;
    }
    if (error != null) {
      return Uri.parse('si.smilelabs.drshine:/callback?error=$error');
    }
    final ticket = 'ticket-${opened.length}';
    api.tickets[ticket] = ticketChallenge ?? url.queryParameters['challenge']!;
    return Uri.parse('si.smilelabs.drshine:/callback?ticket=$ticket');
  }
}

/// The phone's unlock, faked: Face ID, fingerprint or passcode.
class FakeDeviceUnlock implements DeviceUnlock {
  /// False for a phone with no Face ID, fingerprint or passcode.
  bool screenLock = true;

  /// What the phone answers to the next prompt.
  UnlockResult answer = UnlockResult.unlocked;

  /// How many times the prompt came up.
  int asked = 0;

  @override
  Future<bool> hasScreenLock() async => screenLock;

  @override
  Future<UnlockResult> ask() async {
    asked++;
    return screenLock ? answer : UnlockResult.noScreenLock;
  }
}

/// Starts the whole app with [api] and [store] and lets it settle.
///
/// [browser] is the sign-in sheet (a [FakeBrowserSignIn] by default);
/// [webPreview] starts the app without one, as in the web preview.
/// [unlock] adds the app lock, on [clock]'s time; without it there is none.
Future<AppState> pumpApp(
  WidgetTester tester,
  FakeApi api,
  MemorySessionStore store, {
  BrowserSignIn? browser,
  bool webPreview = false,
  DeviceUnlock? unlock,
  DateTime Function()? clock,
}) async {
  final state = AppState(
    api: api,
    store: store,
    browser: webPreview ? null : browser ?? FakeBrowserSignIn(api),
  );
  final lock = unlock == null
      ? null
      : AppLock(state: state, unlocker: unlock, clock: clock);
  await tester.pumpWidget(DrShineApp(state: state, lock: lock));
  await state.start();
  await tester.pumpAndSettle();
  return state;
}
