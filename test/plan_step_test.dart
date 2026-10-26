import 'package:drshine/api/api_client.dart';
import 'package:drshine/screens/order/plan_step.dart';
import 'package:drshine/state/order_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';

void main() {
  Future<FakeApi> pumpPlan(WidgetTester tester) async {
    final api = FakeApi(order: orderJson());
    final builder = OrderBuilder(api: api, order: Order.fromJson(orderJson()), userCanSend: true);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: PlanStep(builder: builder))));
    return api;
  }

  testWidgets('a plan is saved as soon as it is picked', (tester) async {
    final api = await pumpPlan(tester);

    await tester.tap(find.byKey(const Key('plan-flexible')));
    await tester.pumpAndSettle();

    expect(api.orderData['plan_choice']['kind'], 'flexible');
  });

  testWidgets('Complete waits for adult or growing before saving', (tester) async {
    final api = await pumpPlan(tester);

    await tester.tap(find.byKey(const Key('plan-complete')));
    await tester.pumpAndSettle();
    expect(api.orderData['plan_choice']['kind'], isNull);
    expect(find.text('Choose adult or growing patient.'), findsOneWidget);

    await tester.tap(find.text('Growing patient'));
    await tester.pumpAndSettle();
    expect(api.orderData['plan_choice'], containsPair('audience', 'growing'));
  });
}
