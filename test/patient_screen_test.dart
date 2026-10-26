import 'package:drshine/state/session_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';

Future<void> openPatient(WidgetTester tester, FakeApi api) async {
  await pumpApp(tester, api, MemorySessionStore(token: 'saved'));
  await tester.tap(find.text('Test Patient'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'without a draft the patient screen offers a new Aligners order',
    (tester) async {
      await openPatient(tester, FakeApi());

      expect(find.byKey(const Key('new-order')), findsOneWidget);
      expect(find.byKey(const Key('continue-order')), findsNothing);
      expect(find.text('No orders yet. Ready when you are.'), findsOneWidget);
    },
  );

  testWidgets('an open Aligners draft is continued, not started again', (
    tester,
  ) async {
    final api = FakeApi()
      ..patientOrders = [
        {
          'id': 'o-2',
          'reference': 'O2',
          'type': 'aligner_series',
          'type_label': 'Aligners',
          'series': 2,
          'status': 'draft',
          'status_label': 'Draft',
          'draft': true,
        },
        {
          'id': 'o-1',
          'reference': 'O1',
          'type': 'aligner_series',
          'type_label': 'Aligners',
          'series': 1,
          'status': 'shipped',
          'status_label': 'Shipped',
          'draft': false,
        },
      ];
    await openPatient(tester, api);

    expect(find.text('Continue series 2'), findsOneWidget);
    expect(find.byKey(const Key('new-order')), findsNothing);
    expect(find.text('Aligners · series 1'), findsOneWidget);
  });
}
