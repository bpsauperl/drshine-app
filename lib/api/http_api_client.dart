import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'api_client.dart';

/// [ApiClient] over HTTPS with `package:http`.
class HttpApiClient implements ApiClient {
  HttpApiClient({
    String baseUrl = defaultServerUrl,
    this.token,
    http.Client? client,
    this.onUnauthorized,
  }) : _baseUrl = normalizeBaseUrl(baseUrl),
       _client = client ?? http.Client();

  final http.Client _client;
  String _baseUrl;

  @override
  String? token;

  /// Called when the server answers `401`, so the app can go back to sign-in.
  void Function()? onUnauthorized;

  static const Duration _timeout = Duration(seconds: 30);
  static const Duration _uploadTimeout = Duration(minutes: 3);

  @override
  String get baseUrl => _baseUrl;

  @override
  set baseUrl(String value) => _baseUrl = normalizeBaseUrl(value);

  /// Trims spaces and trailing slashes, and adds `https://` when no scheme is given.
  static String normalizeBaseUrl(String value) {
    var url = value.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    if (url.isNotEmpty && !url.contains('://')) {
      url = 'https://$url';
    }
    return url;
  }

  Uri _uri(String path, [Map<String, String>? query]) => Uri.parse(
    '$_baseUrl/api/app/v1$path',
  ).replace(queryParameters: query == null || query.isEmpty ? null : query);

  Map<String, String> _headers({bool json = true}) => {
    'Accept': 'application/json',
    if (json) 'Content-Type': 'application/json; charset=utf-8',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  Future<Json> _send(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
  }) async {
    final request = http.Request(method, _uri(path, query))
      ..headers.addAll(_headers());
    if (body != null) {
      request.body = jsonEncode(body);
    }
    final response = await _run(
      () async => http.Response.fromStream(await _client.send(request)),
      _timeout,
    );
    return _decode(response);
  }

  Future<http.Response> _run(
    Future<http.Response> Function() call,
    Duration timeout,
  ) async {
    try {
      return await call().timeout(timeout);
    } on TimeoutException {
      throw const ApiException(
        0,
        'The server took too long to answer. Try again.',
      );
    } on http.ClientException {
      throw const ApiException(
        0,
        "Can't reach the server. Check the connection and the server address.",
      );
    }
  }

  Json _decode(http.Response response) {
    Object? decoded;
    if (response.bodyBytes.isNotEmpty) {
      try {
        decoded = jsonDecode(utf8.decode(response.bodyBytes));
      } on FormatException {
        decoded = null;
      }
    }
    final json = decoded is Map
        ? decoded.cast<String, dynamic>()
        : <String, dynamic>{};
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return json;
    }
    throw _error(response.statusCode, json);
  }

  ApiException _error(int status, Json json) {
    if (status == 401) {
      onUnauthorized?.call();
    }
    Map<String, List<String>> lists(Object? value) {
      final out = <String, List<String>>{};
      if (value is Map) {
        value.forEach(
          (key, v) =>
              out['$key'] = v is List ? v.map((e) => '$e').toList() : ['$v'],
        );
      }
      return out;
    }

    final message =
        json['message'] is String && (json['message'] as String).isNotEmpty
        ? json['message'] as String
        : switch (status) {
            401 => 'Please sign in again.',
            403 => "You don't have access to this.",
            404 => "This isn't here any more.",
            409 => "That can't be done right now.",
            422 => 'Please check the fields.',
            429 => 'Too many attempts. Wait a minute and try again.',
            _ => 'Something went wrong on the server ($status). Try again.',
          };
    return ApiException(
      status,
      message,
      errors: lists(json['errors']),
      missing: lists(json['missing']),
    );
  }

  @override
  Future<LoginResult> login({
    required String email,
    required String password,
    required String device,
  }) async => LoginResult.fromJson(
    await _send(
      'POST',
      '/login',
      body: {'email': email, 'password': password, 'device': device},
    ),
  );

  @override
  Future<LoginResult> loginTwoFactor({
    required String challenge,
    required String code,
  }) async => LoginResult.fromJson(
    await _send(
      'POST',
      '/login/two-factor',
      body: {'challenge': challenge, 'code': code},
    ),
  );

  @override
  Future<void> logout() async {
    await _send('POST', '/logout');
  }

  @override
  Future<User> me() async =>
      User.fromJson(_obj((await _send('GET', '/me'))['user']));

  @override
  Future<List<Patient>> patients({String query = ''}) async {
    final json = await _send(
      'GET',
      '/patients',
      query: query.trim().isEmpty ? null : {'q': query.trim()},
    );
    final data = json['data'];
    return data is List
        ? data
              .whereType<Map>()
              .map((m) => Patient.fromJson(m.cast<String, dynamic>()))
              .toList()
        : [];
  }

  @override
  Future<Patient> createPatient(NewPatient patient) async => Patient.fromJson(
    _obj((await _send('POST', '/patients', body: patient.toJson()))['patient']),
  );

  @override
  Future<PatientDetail> patient(String id) async =>
      PatientDetail.fromJson(await _send('GET', '/patients/$id'));

  @override
  Future<Order> createAlignersOrder(String patientId) async => _order(
    await _send(
      'POST',
      '/orders',
      body: {'patient_id': patientId, 'type': 'aligner_series'},
    ),
  );

  @override
  Future<Order> order(String id) async =>
      _order(await _send('GET', '/orders/$id'));

  @override
  Future<Order> choosePlan(
    String orderId, {
    required String kind,
    String? audience,
  }) async => _order(
    await _send(
      'PUT',
      '/orders/$orderId/plan',
      body: {'kind': kind, 'audience': audience},
    ),
  );

  @override
  Future<OrderFile> uploadFile(
    String orderId, {
    required String kind,
    required String slot,
    required Uint8List bytes,
    required String filename,
  }) async {
    final request =
        http.MultipartRequest('POST', _uri('/orders/$orderId/files'))
          ..headers.addAll(_headers(json: false))
          ..fields['kind'] = kind
          ..fields['slot'] = slot
          ..files.add(
            http.MultipartFile.fromBytes('file', bytes, filename: filename),
          );
    final response = await _run(
      () async => http.Response.fromStream(await _client.send(request)),
      _uploadTimeout,
    );
    return OrderFile.fromJson(_obj(_decode(response)['file']));
  }

  @override
  Future<void> deleteFile(String orderId, String fileId) async {
    await _send('DELETE', '/orders/$orderId/files/$fileId');
  }

  @override
  Future<Uint8List> fileBytes(String orderId, String fileId) async {
    final response = await _run(
      () => _client.get(
        _uri('/orders/$orderId/files/$fileId'),
        headers: _headers(json: false),
      ),
      _timeout,
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.bodyBytes;
    }
    throw _decodeError(response);
  }

  ApiException _decodeError(http.Response response) {
    try {
      _decode(response);
    } on ApiException catch (error) {
      return error;
    }
    return ApiException(
      response.statusCode,
      'Something went wrong. Try again.',
    );
  }

  @override
  Future<Order> saveRx(String orderId, Rx rx) async =>
      _order(await _send('PUT', '/orders/$orderId/rx', body: rx.toJson()));

  @override
  Future<ScanInbox> scans(String orderId) async =>
      ScanInbox.fromJson(await _send('GET', '/orders/$orderId/scans'));

  @override
  Future<Order> importScan(String orderId, String scanId) async =>
      _order(await _send('POST', '/orders/$orderId/scans/$scanId/import'));

  @override
  Future<Order> submit(String orderId, List<String> attest) async => _order(
    await _send('POST', '/orders/$orderId/submit', body: {'attest': attest}),
  );

  Order _order(Json json) => Order.fromJson(_obj(json['order']));

  Json _obj(Object? value) {
    if (value is Map) {
      return value.cast<String, dynamic>();
    }
    throw const ApiException(
      500,
      'The server sent an answer the app does not understand.',
    );
  }
}
