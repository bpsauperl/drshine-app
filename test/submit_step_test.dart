import 'package:drshine/api/api_client.dart';
import 'package:drshine/screens/order/submit_step.dart';
import 'package:drshine/state/order_builder.dart';
import 'package:drshine/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';

void main() {
  testWidgets('what is still needed shows one line per step', (tester) async {
    final json = orderJson(
      planKind: 'flexible',
      taken: {'frontal'},
      scans: false,
      rx: true,
    );
    final builder = OrderBuilder(
      api: FakeApi(order: json),
      order: Order.fromJson(json),
      userCanSend: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        home: Scaffold(
          body: SubmitStep(builder: builder, onSent: () {}),
        ),
      ),
    );

    expect(
      find.text('${requiredSlots().length - 1} photos missing'),
      findsOneWidget,
    );
    expect(find.text('2 scans missing'), findsOneWidget);
    expect(find.textContaining('photo is missing'), findsNothing);
  });
}
