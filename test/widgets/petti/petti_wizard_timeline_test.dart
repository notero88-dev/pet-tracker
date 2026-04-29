import 'package:flutter_test/flutter_test.dart';
import 'package:pettrack_app/screens/onboarding/mode8_wizard_state.dart';
import 'package:pettrack_app/widgets/petti/petti_wizard_timeline.dart';

void main() {
  group('PettiWizardTimeline.forWizardState', () {
    test('idle state shows all rows pending', () {
      final t = PettiWizardTimeline.forWizardState(Mode8WizardState.idle);
      expect(t.entries, hasLength(5));
      expect(t.entries.every((e) => e.status == PettiTimelineStatus.pending),
          isTrue);
    });

    test('scanning makes row 0 active and the rest pending', () {
      final t = PettiWizardTimeline.forWizardState(Mode8WizardState.scanning);
      expect(t.entries[0].status, PettiTimelineStatus.active);
      for (final entry in t.entries.skip(1)) {
        expect(entry.status, PettiTimelineStatus.pending);
      }
    });

    test('settingHomeZone has rows 0–1 done, row 2 active, rest pending', () {
      final t = PettiWizardTimeline.forWizardState(
          Mode8WizardState.settingHomeZone);
      expect(t.entries[0].status, PettiTimelineStatus.done);
      expect(t.entries[1].status, PettiTimelineStatus.done);
      expect(t.entries[2].status, PettiTimelineStatus.active);
      expect(t.entries[3].status, PettiTimelineStatus.pending);
      expect(t.entries[4].status, PettiTimelineStatus.pending);
    });

    test('creatingTraccarGeofence is the last active row', () {
      final t = PettiWizardTimeline.forWizardState(
          Mode8WizardState.creatingTraccarGeofence);
      for (var i = 0; i < 4; i++) {
        expect(t.entries[i].status, PettiTimelineStatus.done,
            reason: 'row $i should be done');
      }
      expect(t.entries[4].status, PettiTimelineStatus.active);
    });

    test('success makes every row done', () {
      final t = PettiWizardTimeline.forWizardState(Mode8WizardState.success);
      expect(t.entries.every((e) => e.status == PettiTimelineStatus.done),
          isTrue);
    });

    test('error stays at pending — UI should switch to error chrome instead', () {
      final t = PettiWizardTimeline.forWizardState(Mode8WizardState.error);
      expect(t.entries.every((e) => e.status == PettiTimelineStatus.pending),
          isTrue);
    });

    test('every entry has Spanish copy from the design', () {
      final t = PettiWizardTimeline.forWizardState(Mode8WizardState.scanning);
      expect(t.entries[0].label, 'Escuchando tu casa');
      expect(t.entries[1].label, 'Marcando los muros');
      expect(t.entries[2].label, 'Dibujando el círculo en el GPS');
      expect(t.entries[3].label, 'Activando modo casa');
      expect(t.entries[4].label, 'Sincronizando con la nube');
    });
  });
}
