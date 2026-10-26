import 'dart:typed_data';

import 'package:drshine/api/api_client.dart';
import 'package:drshine/state/order_builder.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';

OrderBuilder builderFor(
  Map<String, dynamic> json, {
  bool userCanSend = true,
  FakeApi? api,
}) => OrderBuilder(
  api: api ?? FakeApi(order: json),
  order: Order.fromJson(json),
  userCanSend: userCanSend,
);

void main() {
  group('steps', () {
    test('Plan shows only when the server asks for it', () {
      expect(
        builderFor(orderJson(asksPlan: true)).steps.first,
        BuilderStep.plan,
      );
      expect(builderFor(orderJson(asksPlan: false)).steps, [
        BuilderStep.photos,
        BuilderStep.scans,
        BuilderStep.rx,
        BuilderStep.submit,
      ]);
    });

    test('a new order starts on the first open step', () {
      expect(builderFor(orderJson()).current, BuilderStep.plan);
      expect(
        builderFor(orderJson(planKind: 'flexible')).current,
        BuilderStep.photos,
      );
      expect(
        builderFor(
          orderJson(
            planKind: 'flexible',
            taken: requiredSlots(),
            scans: true,
            rx: true,
          ),
        ).current,
        BuilderStep.submit,
      );
    });

    test('completion follows the server, scans cover impressions and CBCT', () {
      final b = builderFor(
        orderJson(
          planKind: 'complete',
          audience: 'adult',
          taken: requiredSlots(),
          scans: false,
          rx: true,
        ),
      );
      expect(b.isComplete(BuilderStep.plan), isTrue);
      expect(b.isComplete(BuilderStep.photos), isTrue);
      expect(b.isComplete(BuilderStep.scans), isFalse);
      expect(b.isComplete(BuilderStep.rx), isTrue);
      expect(b.isComplete(BuilderStep.submit), isFalse);
    });

    test('completion is derived locally when the server sends no steps', () {
      final json = orderJson(planKind: 'complete', taken: {'frontal'})
        ..['steps'] = [];
      final b = builderFor(json);
      expect(
        b.isComplete(BuilderStep.plan),
        isFalse,
        reason: 'Complete needs adult or growing',
      );
      expect(b.isComplete(BuilderStep.photos), isFalse);
    });
  });

  group('photos', () {
    test('counts the required photos taken', () {
      final b = builderFor(
        orderJson(taken: {...requiredSlots().take(11), 'panoramic_xray'}),
      );
      expect(b.requiredPhotos, 12);
      expect(b.takenRequiredPhotos, 11);
      expect(b.photoCountLabel, '11 of 12');
      expect(b.photoGroups.map((g) => g.key), [
        'Face photos',
        'Intraoral photos',
        'X-ray photos',
        'Additional photos',
      ]);
      expect(b.order.photos, hasLength(18));
    });

    test(
      'an upload marks the slot as uploading, then reloads the order',
      () async {
        final api = FakeApi(order: orderJson());
        final b = builderFor(api.orderData, api: api);
        api.orderData = orderJson(taken: {'frontal'});
        final upload = b.uploadPhoto('frontal', Uint8List.fromList([1, 2, 3]));
        expect(b.uploading, contains('frontal'));
        expect(await upload, isTrue);
        expect(b.uploading, isEmpty);
        expect(api.uploads, ['frontal']);
        expect(b.takenRequiredPhotos, 1);
      },
    );

    test('a failed upload keeps the error on the slot', () async {
      final api = FakeApi()
        ..failNext = const ApiException(422, 'Photos are JPEG or PNG.');
      final b = builderFor(api.orderData, api: api);
      expect(await b.uploadPhoto('frontal', Uint8List(3)), isFalse);
      expect(b.slotErrors['frontal'], 'Photos are JPEG or PNG.');
      expect(b.localPhotos, isEmpty);
    });
  });

  group('missing', () {
    test('lists what is missing per step, in step order', () {
      final b = builderFor(
        orderJson(planKind: 'flexible', taken: requiredSlots()),
      );
      expect(b.missing.map((m) => (m.step, m.text)), [
        (BuilderStep.scans, 'Upper jaw scan is missing'),
        (BuilderStep.scans, 'Lower jaw scan is missing'),
        (BuilderStep.rx, 'Choose who plans the case'),
        (BuilderStep.rx, 'Choose the arches'),
      ]);
    });

    test('is empty when the order is ready', () {
      expect(
        builderFor(
          orderJson(
            planKind: 'flexible',
            taken: requiredSlots(),
            scans: true,
            rx: true,
          ),
        ).missing,
        isEmpty,
      );
    });
  });

  group('attestations and sending', () {
    Map<String, dynamic> ready({bool canSend = true}) => orderJson(
      planKind: 'flexible',
      taken: requiredSlots(),
      scans: true,
      rx: true,
      canSend: canSend,
    );

    test('every card must be ticked before sending', () {
      final b = builderFor(ready());
      expect(b.allAttested, isFalse);
      expect(b.canSubmit, isFalse);
      b.toggleAttestation('P1');
      b.toggleAttestation('P2');
      expect(b.canSubmit, isFalse);
      b.toggleAttestation('P3');
      expect(b.allAttested, isTrue);
      expect(b.canSubmit, isTrue);
      b.toggleAttestation('P2');
      expect(b.isTicked('P2'), isFalse);
      expect(b.canSubmit, isFalse);
    });

    test('only a dentist can send', () {
      final b = builderFor(ready(), userCanSend: false);
      for (final id in ['P1', 'P2', 'P3']) {
        b.toggleAttestation(id);
      }
      expect(b.canSend, isFalse);
      expect(b.canSubmit, isFalse);
    });

    test('a missing item blocks sending', () {
      final b = builderFor(
        orderJson(planKind: 'flexible', taken: requiredSlots(), rx: true),
      );
      for (final id in ['P1', 'P2', 'P3']) {
        b.toggleAttestation(id);
      }
      expect(b.canSubmit, isFalse);
    });

    test('submit sends the ticked cards, in order', () async {
      final api = FakeApi(order: ready());
      final b = builderFor(api.orderData, api: api);
      for (final id in ['P3', 'P1', 'P2']) {
        b.toggleAttestation(id);
      }
      expect(await b.submit(), isTrue);
      expect(api.submitted, ['P1', 'P2', 'P3']);
      expect(b.sent, isTrue);
      expect(b.isComplete(BuilderStep.submit), isTrue);
    });

    test('a 422 on submit shows what the server says is missing', () async {
      final api = FakeApi(order: ready())
        ..failNext = const ApiException(
          422,
          'Still needed: scans.',
          missing: {
            'impressions': ['Upper jaw scan is missing'],
          },
        );
      final b = builderFor(api.orderData, api: api);
      for (final id in ['P1', 'P2', 'P3']) {
        b.toggleAttestation(id);
      }
      expect(await b.submit(), isFalse);
      expect(b.error, 'Still needed: scans.');
      expect(b.missing.single.text, 'Upper jaw scan is missing');
      expect(b.missing.single.step, BuilderStep.scans);
    });
  });

  group('rx', () {
    test('quick phrases are added once, on their own line', () {
      final b = builderFor(orderJson());
      b.addPhrase('Keep the midlines.');
      b.addPhrase('Attachments allowed.');
      b.addPhrase('Keep the midlines.');
      expect(
        b.rxDraft.prescription,
        'Keep the midlines.\nAttachments allowed.',
      );
      expect(b.rxDirty, isTrue);
    });

    test('leaving the RX step saves the draft', () async {
      final api = FakeApi(order: orderJson(asksPlan: false));
      final b = builderFor(api.orderData, api: api);
      await b.goTo(BuilderStep.rx);
      b.editRx(
        b.rxDraft.copyWith(planningPartner: 'shine_planning', arches: 'dual'),
      );
      b.toggleConcern('crowding');
      await b.goTo(BuilderStep.submit);
      expect(api.savedRx?.planningPartner, 'shine_planning');
      expect(api.savedRx?.concerns, ['crowding']);
      expect(b.rxDirty, isFalse);
    });
  });
}
