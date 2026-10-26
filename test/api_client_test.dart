import 'dart:convert';
import 'dart:typed_data';

import 'package:drshine/api/api_client.dart';
import 'package:drshine/api/http_api_client.dart';
import 'package:drshine/util/format.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'fixtures.dart';

http.Response json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json; charset=utf-8'});

void main() {
  group('HttpApiClient', () {
    test('signs in and parses the user', () async {
      late http.Request sent;
      final api = HttpApiClient(
        baseUrl: 'https://example.test/',
        client: MockClient((request) async {
          sent = request;
          return json({'token': 'tok', 'user': userJson(canSend: false)});
        }),
      );
      final result = await api.login(email: 'a@b.test', password: 'pw', device: 'drShine on iPhone');
      expect(sent.url.toString(), 'https://example.test/api/app/v1/login');
      expect(jsonDecode(sent.body), {'email': 'a@b.test', 'password': 'pw', 'device': 'drShine on iPhone'});
      expect(result.needsTwoFactor, isFalse);
      expect(result.token, 'tok');
      expect(result.user!.canSend, isFalse);
      expect(result.user!.clinic!.name, 'Example Dental Clinic');
      expect(result.user!.id, '7');
    });

    test('a two-step sign-in returns the challenge', () async {
      final api = HttpApiClient(client: MockClient((_) async => json({'two_factor': true, 'challenge': 'abc'})));
      final result = await api.login(email: 'a@b.test', password: 'pw', device: 'x');
      expect(result.needsTwoFactor, isTrue);
      expect(result.challenge, 'abc');
    });

    test('sends the Bearer token and the search query', () async {
      late http.Request sent;
      final api = HttpApiClient(
        baseUrl: 'example.test',
        token: 'tok',
        client: MockClient((request) async {
          sent = request;
          return json({'data': [patientJson()]});
        }),
      );
      final patients = await api.patients(query: ' test ');
      expect(sent.headers['Authorization'], 'Bearer tok');
      expect(sent.url.toString(), 'https://example.test/api/app/v1/patients?q=test');
      expect(patients.single.name, 'Test Patient');
      expect(patients.single.initials, 'TP');
      expect(patients.single.doctor!.name, 'Dr. Example Doctor');
    });

    test('parses the full order', () async {
      final api = HttpApiClient(
        client: MockClient((_) async => json({'order': orderJson(planKind: 'complete', audience: 'growing', taken: {'frontal'})})),
      );
      final order = await api.order('o-1');
      expect(order.reference, 'O1A2B3C4');
      expect(order.draft, isTrue);
      expect(order.planChoice.asks, isTrue);
      expect(order.planChoice.isChosen, isTrue);
      expect(order.planChoice.audience, 'growing');
      expect(order.photos, hasLength(18));
      expect(order.photos.where((p) => p.required), hasLength(12));
      expect(order.photos.firstWhere((p) => p.slot == 'frontal').file!.id, 'f-frontal');
      expect(order.photos.first.guide, 'face-front');
      expect(order.scans.map((s) => s.slot), ['upper_scan', 'lower_scan']);
      expect(order.step('impressions')!.status, 'No scans yet');
      expect(order.missing['rx'], ['Choose who plans the case', 'Choose the arches']);
      expect(order.options.partners.first.description, isNotEmpty);
      expect(order.priceLines[1].amountCents, isNull);
      expect(order.totalCents, 115000);
      expect(order.attestations.map((a) => a.id), ['P1', 'P2', 'P3']);
    });

    test('a 422 carries the messages per field and what is missing', () async {
      final api = HttpApiClient(
        client: MockClient((_) async => json({
              'message': 'Still needed: scans.',
              'errors': {'attest': ['Please confirm: P2.']},
              'missing': {'impressions': ['Upper jaw scan is missing'], 'rx': []},
            }, 422)),
      );
      await expectLater(
        api.submit('o-1', ['P1']),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'status', 422)
            .having((e) => e.message, 'message', 'Still needed: scans.')
            .having((e) => e.errorFor('attest'), 'attest', 'Please confirm: P2.')
            .having((e) => e.missing['impressions'], 'missing', ['Upper jaw scan is missing'])),
      );
    });

    test('a 401 tells the app the session ended', () async {
      var expired = false;
      final api = HttpApiClient(client: MockClient((_) async => json({}, 401)), onUnauthorized: () => expired = true);
      await expectLater(api.me(), throwsA(isA<ApiException>().having((e) => e.isUnauthorized, 'unauthorized', isTrue)));
      expect(expired, isTrue);
    });

    test('a network failure says the server cannot be reached', () async {
      final api = HttpApiClient(client: MockClient((_) async => throw http.ClientException('offline')));
      await expectLater(api.me(), throwsA(isA<ApiException>().having((e) => e.isOffline, 'offline', isTrue)));
    });

    test('uploads a photo as multipart with kind and slot', () async {
      late http.Request sent;
      final api = HttpApiClient(
        token: 'tok',
        client: MockClient((request) async {
          sent = request;
          return json({'file': {'id': 'f-9', 'slot': 'overjet', 'name': 'overjet.jpg', 'url': 'u'}}, 201);
        }),
      );
      final file = await api.uploadFile('o-1',
          kind: 'photo', slot: 'overjet', bytes: Uint8List.fromList([1, 2, 3]), filename: 'overjet.jpg');
      expect(sent.url.path, '/api/app/v1/orders/o-1/files');
      expect(sent.headers['content-type'], startsWith('multipart/form-data'));
      expect(sent.headers['Authorization'], 'Bearer tok');
      final body = utf8.decode(sent.bodyBytes, allowMalformed: true);
      expect(body, contains('name="kind"'));
      expect(body, contains('overjet'));
      expect(body, contains('filename="overjet.jpg"'));
      expect(file.id, 'f-9');
      expect(file.slot, 'overjet');
    });

    test('reads the Scan Hub inbox', () async {
      final api = HttpApiClient(
        client: MockClient((_) async => json({
              'connected': true,
              'scans': [
                {'id': 's1', 'source': 'iTero', 'patient_name': 'Test Patient', 'taken_at': '2026-10-20T10:00:00+02:00', 'jaws': ['upper', 'lower'], 'match': 'exact'},
              ],
            })),
      );
      final inbox = await api.scans('o-1');
      expect(inbox.connected, isTrue);
      expect(inbox.scans.single.jaws, ['upper', 'lower']);
      expect(inbox.scans.single.takenAt, isNotNull);
    });

    test('normalizes the server address', () {
      expect(HttpApiClient.normalizeBaseUrl(' example.test/ '), 'https://example.test');
      expect(HttpApiClient.normalizeBaseUrl('http://127.0.0.1:8030//'), 'http://127.0.0.1:8030');
    });
  });

  group('formatEuros', () {
    test('uses a dot for thousands and a comma for cents', () {
      expect(formatEuros(115000), '€1.150');
      expect(formatEuros(10000), '€100');
      expect(formatEuros(9950), '€99,50');
      expect(formatEuros(123456789), '€1.234.567,89');
      expect(formatEuros(0), '€0');
      expect(formatEuros(null), '');
    });
  });
}
