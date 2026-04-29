import 'package:flutter_test/flutter_test.dart';
import 'package:pettrack_app/screens/onboarding/mode8_wizard_state.dart';

void main() {
  group('Mode8WizardState — labels', () {
    test('idle and error have non-progress labels', () {
      expect(Mode8WizardState.idle.label, '');
      expect(Mode8WizardState.error.label, 'Algo salió mal');
    });

    test('every in-flight state has a Spanish label', () {
      for (final s in [
        Mode8WizardState.scanning,
        Mode8WizardState.settingMacs,
        Mode8WizardState.settingHomeZone,
        Mode8WizardState.enteringMode8,
        Mode8WizardState.creatingTraccarGeofence,
      ]) {
        expect(s.label, isNotEmpty, reason: '$s missing label');
        expect(s.label, endsWith('…'), reason: '$s should hint progress');
      }
    });

    test('success has a celebratory label', () {
      expect(Mode8WizardState.success.label, '¡Listo!');
    });
  });

  group('Mode8WizardState — progress', () {
    test('progress is monotonically non-decreasing through happy path', () {
      final happyPath = [
        Mode8WizardState.idle,
        Mode8WizardState.scanning,
        Mode8WizardState.settingMacs,
        Mode8WizardState.settingHomeZone,
        Mode8WizardState.enteringMode8,
        Mode8WizardState.creatingTraccarGeofence,
        Mode8WizardState.success,
      ];
      for (var i = 0; i < happyPath.length - 1; i++) {
        final a = happyPath[i].progress;
        final b = happyPath[i + 1].progress;
        expect(b, greaterThanOrEqualTo(a),
            reason: '${happyPath[i + 1]} progress regressed from ${happyPath[i]}');
      }
    });

    test('error state resets to 0', () {
      expect(Mode8WizardState.error.progress, 0.0);
    });

    test('success is 1.0', () {
      expect(Mode8WizardState.success.progress, 1.0);
    });
  });

  group('Mode8WizardState — isInFlight', () {
    test('returns true only for in-flight states', () {
      expect(Mode8WizardState.idle.isInFlight, isFalse);
      expect(Mode8WizardState.success.isInFlight, isFalse);
      expect(Mode8WizardState.error.isInFlight, isFalse);

      expect(Mode8WizardState.scanning.isInFlight, isTrue);
      expect(Mode8WizardState.settingMacs.isInFlight, isTrue);
      expect(Mode8WizardState.settingHomeZone.isInFlight, isTrue);
      expect(Mode8WizardState.enteringMode8.isInFlight, isTrue);
      expect(Mode8WizardState.creatingTraccarGeofence.isInFlight, isTrue);
    });
  });
}
