import 'dart:typed_data';

import 'models.dart';

export 'models.dart';

/// The drShine production (DEV) server the app talks to by default.
const String defaultServerUrl =
    'https://drshine-production-8tmpnh.laravel.cloud';

/// An API error with the server's own message.
class ApiException implements Exception {
  const ApiException(
    this.statusCode,
    this.message, {
    this.errors = const {},
    this.missing = const {},
  });

  /// The HTTP status, or 0 when the server could not be reached.
  final int statusCode;
  final String message;

  /// Validation errors (`422`) per field.
  final Map<String, List<String>> errors;

  /// What is missing before an order can be sent (`422` on submit).
  final Map<String, List<String>> missing;

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isOffline => statusCode == 0;

  /// The first validation message for [field], if any.
  String? errorFor(String field) =>
      errors[field]?.isNotEmpty == true ? errors[field]!.first : null;

  @override
  String toString() => message;
}

/// Everything the app asks of the server (contract v1, section A).
///
/// The real implementation is [HttpApiClient]; widget tests use a fake.
abstract class ApiClient {
  /// The server, e.g. `https://drshine-production-8tmpnh.laravel.cloud`.
  String get baseUrl;
  set baseUrl(String value);

  /// The Bearer token, or null when signed out.
  String? get token;
  set token(String? value);

  Future<LoginResult> login({
    required String email,
    required String password,
    required String device,
  });
  Future<LoginResult> loginTwoFactor({
    required String challenge,
    required String code,
  });
  Future<void> logout();
  Future<User> me();

  Future<List<Patient>> patients({String query = ''});
  Future<Patient> createPatient(NewPatient patient);
  Future<PatientDetail> patient(String id);

  Future<Order> createAlignersOrder(String patientId);
  Future<Order> order(String id);
  Future<Order> choosePlan(
    String orderId, {
    required String kind,
    String? audience,
  });
  Future<OrderFile> uploadFile(
    String orderId, {
    required String kind,
    required String slot,
    required Uint8List bytes,
    required String filename,
  });
  Future<void> deleteFile(String orderId, String fileId);
  Future<Uint8List> fileBytes(String orderId, String fileId);
  Future<Order> saveRx(String orderId, Rx rx);
  Future<ScanInbox> scans(String orderId);
  Future<Order> importScan(String orderId, String scanId);
  Future<Order> submit(String orderId, List<String> attest);
}
