import 'dart:ui' as ui;

import 'package:drshine/api/api_client.dart';
import 'package:drshine/screens/camera/blueprint.dart';
import 'package:drshine/screens/camera/guided_camera_screen.dart';
import 'package:drshine/state/order_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';

void main() {
  group('blueprintFor', () {
    test('every slot gets its own outline, facing the right way', () {
      final expected = {
        'frontal': Blueprint.faceFront,
        'frontal_smile': Blueprint.faceFrontSmile,
        'left_profile': Blueprint.profileLeft,
        'right_profile_smile': Blueprint.profileRight,
        'front_arches': Blueprint.frontArches,
        'left_bite': Blueprint.buccalLeft,
        'right_bite': Blueprint.buccalRight,
        'occlusal_upper': Blueprint.occlusalUpper,
        'occlusal_lower': Blueprint.occlusalLower,
        'overjet': Blueprint.overjet,
        'panoramic_xray': Blueprint.xray,
        'lateral_cephalometric': Blueprint.xray,
        'left_front_45_smile': Blueprint.threeQuarterLeft,
        'right_front_45': Blueprint.threeQuarterRight,
      };
      expected.forEach(
        (slot, blueprint) =>
            expect(blueprintFor(slot), blueprint, reason: slot),
      );
    });

    test('falls back to the guide key for slots the app does not know', () {
      expect(
        blueprintFor('new_slot', 'occlusal-lower'),
        Blueprint.occlusalLower,
      );
      expect(
        blueprintFor('new_slot', 'frontal-smile'),
        Blueprint.faceFrontSmile,
      );
      expect(blueprintFor('new_slot', 'xray'), Blueprint.xray);
      expect(blueprintFor('new_slot', 'something-else'), Blueprint.faceFront);
    });

    test('the front arches say retractors in, teeth together', () {
      expect(
        instructionFor('front_arches', Blueprint.frontArches),
        'Retractors in, teeth together.',
      );
    });
  });

  group('BlueprintPainter', () {
    test('draws every outline as faded white strokes', () {
      for (final blueprint in Blueprint.values) {
        final painter = BlueprintPainter(blueprint);
        expect(painter.opacity, 0.35);
        final recorder = ui.PictureRecorder();
        painter.paint(Canvas(recorder), const Size(390, 844));
        recorder.endRecording().dispose();
      }
    });

    test('fits the drawing inside the screen', () {
      for (final blueprint in Blueprint.values) {
        final frame = BlueprintPainter(blueprint)
            .frameFor(const Size(390, 844));
        expect(frame.left, greaterThanOrEqualTo(0));
        expect(frame.top, greaterThanOrEqualTo(0));
        expect(frame.right, lessThanOrEqualTo(390));
        expect(frame.bottom, lessThanOrEqualTo(844));
      }
    });

    test('repaints only when the outline changes', () {
      final a = BlueprintPainter(Blueprint.overjet);
      expect(a.shouldRepaint(BlueprintPainter(Blueprint.overjet)), isFalse);
      expect(a.shouldRepaint(BlueprintPainter(Blueprint.xray)), isTrue);
    });
  });

  testWidgets(
    'the guided camera shows the outline, instruction and slot arrows',
    (tester) async {
      final api = FakeApi();
      final builder = OrderBuilder(
        api: api,
        order: Order.fromJson(api.orderData),
        userCanSend: true,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: GuidedCameraScreen(
            builder: builder,
            startSlot: 'front_arches',
            cameraEnabled: false,
          ),
        ),
      );

      expect(find.text('Front arches'), findsOneWidget);
      expect(find.text('7 of 18'), findsOneWidget);
      expect(find.text('Retractors in, teeth together.'), findsOneWidget);
      expect(find.text('Camera unavailable here'), findsOneWidget);
      final paint = tester.widget<CustomPaint>(
        find.byKey(const Key('blueprint')),
      );
      expect(
        (paint.painter! as BlueprintPainter).blueprint,
        Blueprint.frontArches,
      );

      await tester.tap(find.byTooltip('Next photo'));
      await tester.pump();
      expect(find.text('Left bite'), findsOneWidget);
      expect(
        (tester.widget<CustomPaint>(find.byKey(const Key('blueprint'))).painter!
                as BlueprintPainter)
            .blueprint,
        Blueprint.buccalLeft,
      );

      await tester.tap(find.byTooltip('Previous photo'));
      await tester.tap(find.byTooltip('Previous photo'));
      await tester.pump();
      expect(find.text('Right profile'), findsOneWidget);
    },
  );
}
