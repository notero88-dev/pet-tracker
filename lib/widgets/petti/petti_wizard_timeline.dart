// Petti onboarding — Zona de casa wizard timeline (A6.3).
//
// The "hero" waiting moment of the home-zone setup. Renders a vertical
// timeline with one entry per backend step, animating each one through
// pending → active → done as the wizard progresses. The Sabana/home
// glyph at top and the "Enseñándole a tu Petti dónde es casa." headline
// belong to the parent screen; this widget is just the timeline list.
//
// Source: design package screens-a6.jsx (A6_Configuring).
// 2026-04-29 design delivery.

import 'package:flutter/material.dart';

import '../../screens/onboarding/mode8_wizard_state.dart';
import '../../utils/petti_theme.dart';

/// A single entry in the wizard timeline — what to show, what state it's in.
class PettiTimelineEntry {
  final String label;
  final String detail;
  final PettiTimelineStatus status;

  const PettiTimelineEntry({
    required this.label,
    required this.detail,
    required this.status,
  });
}

enum PettiTimelineStatus { pending, active, done }

/// Vertical 5-step timeline matching the design's A6.3 hero. Each row
/// has a status dot (Sabana for done, Marigold-ringed for active, dim
/// for pending), a connector line down to the next row, and label/detail
/// text. The "active" row gets a small "en curso" pill on the right.
class PettiWizardTimeline extends StatelessWidget {
  final List<PettiTimelineEntry> entries;

  const PettiWizardTimeline({super.key, required this.entries});

  /// Convenience constructor that maps an in-flight [Mode8WizardState] +
  /// the designer's canonical 5-step labels into a list of entries.
  /// The wizard's runtime state machine has 6 cases (idle/scanning/
  /// settingMacs/settingHomeZone/enteringMode8/creatingTraccarGeofence
  /// /success/error); the timeline collapses scanning + settingMacs into
  /// the design's first two rows ("Escuchando tu casa" / "Marcando los
  /// muros") because that mapping reflects what the user perceives, not
  /// the backend's internal call boundary.
  factory PettiWizardTimeline.forWizardState(Mode8WizardState state) {
    PettiTimelineStatus statusFor(int index) {
      // Map state → the index of the row currently in flight.
      final activeIndex = _activeRowFor(state);
      if (activeIndex == null) {
        // idle / success / error — show all pending or all done.
        if (state == Mode8WizardState.success) return PettiTimelineStatus.done;
        return PettiTimelineStatus.pending;
      }
      if (index < activeIndex) return PettiTimelineStatus.done;
      if (index == activeIndex) return PettiTimelineStatus.active;
      return PettiTimelineStatus.pending;
    }

    return PettiWizardTimeline(entries: [
      PettiTimelineEntry(
        label: 'Escuchando tu casa',
        detail: 'WiFi cercano',
        status: statusFor(0),
      ),
      PettiTimelineEntry(
        label: 'Marcando los muros',
        detail: '3 anclas registradas',
        status: statusFor(1),
      ),
      PettiTimelineEntry(
        label: 'Dibujando el círculo en el GPS',
        detail: 'zona de casa aplicada al dispositivo',
        status: statusFor(2),
      ),
      PettiTimelineEntry(
        label: 'Activando modo casa',
        detail: 'ahorro de batería',
        status: statusFor(3),
      ),
      PettiTimelineEntry(
        label: 'Sincronizando con la nube',
        detail: 'casi listo',
        status: statusFor(4),
      ),
    ]);
  }

  /// Map wizard state to the timeline row index that is "in flight".
  /// Returns null for non-active states (idle, success, error).
  static int? _activeRowFor(Mode8WizardState state) {
    switch (state) {
      case Mode8WizardState.scanning:
        return 0; // "Escuchando tu casa"
      case Mode8WizardState.settingMacs:
        return 1; // "Marcando los muros"
      case Mode8WizardState.settingHomeZone:
        return 2; // "Dibujando el círculo en el GPS"
      case Mode8WizardState.enteringMode8:
        return 3; // "Activando modo casa"
      case Mode8WizardState.creatingTraccarGeofence:
        return 4; // "Sincronizando con la nube"
      case Mode8WizardState.idle:
      case Mode8WizardState.success:
      case Mode8WizardState.error:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < entries.length; i++)
          _TimelineRow(
            entry: entries[i],
            isLast: i == entries.length - 1,
          ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final PettiTimelineEntry entry;
  final bool isLast;

  const _TimelineRow({required this.entry, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final isDone = entry.status == PettiTimelineStatus.done;
    final isActive = entry.status == PettiTimelineStatus.active;
    final isPending = entry.status == PettiTimelineStatus.pending;

    return Opacity(
      opacity: isPending ? 0.5 : 1,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status dot + connector line column.
            SizedBox(
              width: 24,
              child: Column(
                children: [
                  _StatusDot(status: entry.status),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 1.5,
                        margin: const EdgeInsets.only(top: 4, bottom: 0),
                        color: isDone
                            ? PettiColors.sabana
                            : const Color(0xFFFAF7F2)
                                .withValues(alpha: 0.12),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: PettiSpacing.s3),
            // Label + detail.
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(
                  top: 1,
                  bottom: PettiSpacing.s5 - PettiSpacing.s1,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.label,
                      style: PettiText.bodyStrong()
                          .copyWith(color: PettiColors.fgOnDark, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.detail,
                      style: PettiText.bodySm()
                          .copyWith(color: PettiColors.fgOnDarkDim, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            // Right-side "en curso" tag for the active row.
            if (isActive)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'EN CURSO',
                  style: PettiText.meta().copyWith(
                    color: PettiColors.marigold,
                    fontSize: 10,
                    letterSpacing: 0.06 * 10,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final PettiTimelineStatus status;
  const _StatusDot({required this.status});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case PettiTimelineStatus.done:
        return Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: PettiColors.sabana,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_rounded,
              color: PettiColors.fgOnDark, size: 14),
        );
      case PettiTimelineStatus.active:
        return AnimatedContainer(
          duration: PettiMotion.std,
          curve: PettiMotion.ease,
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: PettiColors.marigoldSoft,
            shape: BoxShape.circle,
            border: Border.all(color: PettiColors.marigold, width: 1.5),
          ),
          child: Center(
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: PettiColors.marigold,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      case PettiTimelineStatus.pending:
        return Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: const Color(0xFFFAF7F2).withValues(alpha: 0.06),
            shape: BoxShape.circle,
          ),
        );
    }
  }
}
