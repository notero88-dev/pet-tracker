// Mode picker — stacked cards variant (the chosen default).
//
// Three modes per the PRD/prototype:
//   realtime   "Tiempo real"  — 10–600s, GPS+TCP always on
//   home       "Modo Casa"    — 10–60s outdoors, sleeps indoors (recommended)
//   deepSleep  "Ahorro"       — 1–24h updates, 12-month battery

import 'package:flutter/material.dart';
import '../../utils/petti_theme.dart';
import 'petti_primitives.dart';

enum PettiMode { realtime, home, deepSleep }

class PettiModeSpec {
  final PettiMode id;
  final String label;
  final String sub;
  final String battery;
  final IconData icon;
  final bool recommended;

  const PettiModeSpec({
    required this.id,
    required this.label,
    required this.sub,
    required this.battery,
    required this.icon,
    this.recommended = false,
  });
}

const List<PettiModeSpec> kPettiModes = [
  PettiModeSpec(
    id: PettiMode.realtime,
    label: 'Tiempo real',
    sub:
        'Actualizaciones cada pocos segundos. Para paseos o momentos importantes.',
    battery: '1–3 días',
    icon: Icons.speed_rounded,
  ),
  PettiModeSpec(
    id: PettiMode.home,
    label: 'Modo Casa',
    sub:
        'Se pone en silencio cuando Canela está en casa. Rastrea solo cuando sale.',
    battery: '~14 días',
    icon: Icons.home_rounded,
    recommended: true,
  ),
  PettiModeSpec(
    id: PettiMode.deepSleep,
    label: 'Ahorro',
    sub: 'Una actualización por hora. Para días tranquilos sin salidas.',
    battery: 'hasta 12 meses',
    icon: Icons.battery_full_rounded,
  ),
];

/// Interval presets per mode. Values are the numeric payloads sent to
/// the backend (seconds for realtime/home; hours for deepSleep).
class PettiIntervalPreset {
  final int value;
  final String label;
  const PettiIntervalPreset(this.value, this.label);
}

Map<PettiMode, List<PettiIntervalPreset>> kPettiIntervalPresets = {
  PettiMode.realtime: const [
    PettiIntervalPreset(10, '10s'),
    PettiIntervalPreset(30, '30s'),
    PettiIntervalPreset(60, '1 min'),
    PettiIntervalPreset(300, '5 min'),
    PettiIntervalPreset(600, '10 min'),
  ],
  PettiMode.home: const [
    PettiIntervalPreset(10, '10s'),
    PettiIntervalPreset(30, '30s'),
    PettiIntervalPreset(60, '1 min'),
  ],
  PettiMode.deepSleep: const [
    PettiIntervalPreset(1, '1 h'),
    PettiIntervalPreset(4, '4 h'),
    PettiIntervalPreset(12, '12 h'),
    PettiIntervalPreset(24, '24 h'),
  ],
};

// -----------------------------------------------------------------------------
// Stacked-card mode picker.
// -----------------------------------------------------------------------------

class PettiModePicker extends StatelessWidget {
  final PettiMode selected;
  final ValueChanged<PettiMode> onChanged;
  final bool disabled;

  const PettiModePicker({
    super.key,
    required this.selected,
    required this.onChanged,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final (i, spec) in kPettiModes.indexed) ...[
          if (i > 0) const SizedBox(height: PettiSpacing.s2),
          _ModeCard(
            spec: spec,
            selected: spec.id == selected,
            disabled: disabled,
            onTap: () => onChanged(spec.id),
          ),
        ],
      ],
    );
  }
}

class _ModeCard extends StatelessWidget {
  final PettiModeSpec spec;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;

  const _ModeCard({
    required this.spec,
    required this.selected,
    required this.disabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected ? PettiColors.marigoldSoft : PettiColors.cloud;
    final borderColor = selected ? PettiColors.marigold : Colors.transparent;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: borderColor, width: 1.5),
        borderRadius: BorderRadius.circular(PettiRadii.md - 2),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: disabled ? null : onTap,
          borderRadius: BorderRadius.circular(PettiRadii.md - 2),
          child: Padding(
            padding: const EdgeInsets.all(PettiSpacing.s3 + 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon tile
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: selected ? Colors.white : PettiColors.sand,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    spec.icon,
                    size: 18,
                    color: selected ? PettiColors.marigoldDim : PettiColors.fg,
                  ),
                ),
                const SizedBox(width: PettiSpacing.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            spec.label,
                            style: PettiText.bodyStrong().copyWith(
                              fontSize: 15,
                              color: PettiColors.midnight,
                            ),
                          ),
                          if (spec.recommended) ...[
                            const SizedBox(width: PettiSpacing.s2),
                            const PettiRecommendedBadge(),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        spec.sub,
                        style: PettiText.bodySm().copyWith(height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Interval stepper — preset chips specific to the active mode.
// -----------------------------------------------------------------------------

class PettiIntervalStepper extends StatelessWidget {
  final PettiMode mode;
  final int value;
  final ValueChanged<int> onChanged;
  final bool disabled;

  const PettiIntervalStepper({
    super.key,
    required this.mode,
    required this.value,
    required this.onChanged,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final presets = kPettiIntervalPresets[mode]!;
    final currentLabel = presets
        .firstWhere(
          (p) => p.value == value,
          orElse: () => presets.first,
        )
        .label;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'INTERVALO',
              style: PettiText.meta().copyWith(letterSpacing: 0.72),
            ),
            Text(
              currentLabel,
              style: PettiText.number(size: 14, weight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: PettiSpacing.s2),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final p in presets)
              _IntervalChip(
                label: p.label,
                selected: p.value == value,
                disabled: disabled,
                onTap: () => onChanged(p.value),
              ),
          ],
        ),
      ],
    );
  }
}

class _IntervalChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;

  const _IntervalChip({
    required this.label,
    required this.selected,
    required this.disabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? PettiColors.marigoldSoft : Colors.white,
      borderRadius: BorderRadius.circular(PettiRadii.sm),
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(PettiRadii.sm),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: PettiSpacing.s3,
            vertical: 8,
          ),
          constraints: const BoxConstraints(minWidth: 58),
          decoration: BoxDecoration(
            border: Border.all(
              color:
                  selected ? PettiColors.marigold : PettiColors.borderLight,
              width: 1,
            ),
            borderRadius: BorderRadius.circular(PettiRadii.sm),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: PettiText.body().copyWith(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? PettiColors.midnight : PettiColors.fg,
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Battery-estimate preview — small marigold-soft card that updates live based
// on selected mode + interval.
// -----------------------------------------------------------------------------

class PettiBatteryEstimateCard extends StatelessWidget {
  final PettiMode mode;
  final int interval;

  const PettiBatteryEstimateCard({
    super.key,
    required this.mode,
    required this.interval,
  });

  String _estimate() {
    switch (mode) {
      case PettiMode.realtime:
        if (interval <= 30) return '~1 día';
        if (interval <= 60) return '~2 días';
        return '~3 días';
      case PettiMode.home:
        return interval <= 30 ? '~14 días' : '~18 días';
      case PettiMode.deepSleep:
        if (interval <= 1) return '~45 días';
        if (interval <= 4) return '~4 meses';
        return '~12 meses';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: PettiSpacing.s3 + 2,
        vertical: PettiSpacing.s3,
      ),
      decoration: BoxDecoration(
        color: PettiColors.marigoldSoft,
        borderRadius: BorderRadius.circular(PettiRadii.sm + 2),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: PettiColors.marigold.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.schedule_rounded,
              size: 16,
              color: PettiColors.marigoldDim,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Batería estimada',
                  style: PettiText.label().copyWith(fontSize: 12),
                ),
                Text(
                  _estimate(),
                  style: PettiText.number(size: 15, weight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
