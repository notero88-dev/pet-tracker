// Regression test for the Android bug Diana reported (2026-07-24): on step 1
// of the Zona de casa wizard the "Empezar" CTA was stranded below the fold on
// short viewports because _IntroStep used a bare Column + Spacer with no
// scroll. This test forces a short viewport (the overflow condition) and
// asserts the step neither overflows nor hides the CTA.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pettrack_app/models/device.dart';
import 'package:pettrack_app/screens/device/home_zone_setup_wizard.dart';

void main() {
  final device = Device(
    id: 1,
    name: 'Test Tracker',
    uniqueId: '860000000000000',
    status: 'active',
    createdAt: DateTime(2026, 1, 1),
  );

  testWidgets(
    'Zona de casa intro CTA is reachable on a short viewport (no overflow)',
    (tester) async {
      // A deliberately short, narrow logical viewport (360 x ~427 dp) — the
      // exact kind of Android screen / large-font-scale combination that
      // pushed the CTA off screen before the fix.
      tester.view.physicalSize = const Size(1080, 1280);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: HomeZoneSetupWizard(device: device, petName: 'Macarron'),
        ),
      );
      await tester.pump();

      // 1) The bare Column + Spacer layout would raise a RenderFlex overflow
      //    on this viewport; the scrollable layout must not.
      expect(
        tester.takeException(),
        isNull,
        reason: 'intro step overflowed — it is not scrollable',
      );

      // 2) The CTA must exist and be reachable by scrolling.
      final cta = find.text('Empezar');
      expect(cta, findsOneWidget);
      await tester.scrollUntilVisible(
        cta,
        120,
        scrollable: find.byType(Scrollable).first,
      );
      expect(cta, findsOneWidget);
    },
  );
}
