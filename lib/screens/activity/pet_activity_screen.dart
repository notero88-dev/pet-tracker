// Pets + Activity Dashboard — Garmin-flavored daily-stats screen for one
// pet at a time, with a horizontal pet picker at the top to swap between
// pets. Mirrors the Petti design delivered 2026-04-23 (project file
// `Pets + Activity Dashboard.html` / `pets-activity.jsx`).
//
// Sections, top to bottom:
//   - Top bar: "ACTIVIDAD / Mis mascotas" + calendar / more icons
//   - Pet picker: horizontal pill scroller
//   - Pet header strip: avatar + name + battery + last-sync + Mapa CTA
//   - Range tabs: Día / Semana / Mes / Año (only Día has data in v1)
//   - Hero rings card: 3 concentric activity rings + legend
//   - Stat tiles 2x2: Pasos · Ritmo prom. · Vel. máx. · Calorías
//   - Weekly chart card: bar chart with goal line + sparkline
//
// Deliberately omitted from this v1 (deferred follow-ups, see KANBAN):
//   - Heart-rate band  → MT710 has no HR sensor
//   - Insight card     → needs deeper analytics
//   - Recent walks list → needs walk-segmentation logic
//
// Numbers are estimated from GPS distance via `services/activity_calculator.dart`.
// V1 takes a list of [DailyActivity] from the caller; the home screen
// builds them with hardcoded mocks today, real Traccar aggregation later.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/daily_activity.dart';
import '../../services/activity_calculator.dart';
import '../../utils/petti_theme.dart';
import 'mock_activity_data.dart' show demoActivities;

class PetActivityScreen extends StatefulWidget {
  /// Static pet list — used by the demo / preview path.
  final List<DailyActivity>? _staticPets;

  /// Async loader — used by the live data path. Errors fall back to
  /// [demoActivities] with a banner so the screen never blanks.
  final Future<List<DailyActivity>> Function()? _loader;

  final String? initialPetId;

  const PetActivityScreen({
    super.key,
    required List<DailyActivity> pets,
    this.initialPetId,
  })  : _staticPets = pets,
        _loader = null;

  /// Async / live variant: loads activity data on first build, shows a
  /// loading skeleton in the meantime, falls back to demo pets on error.
  /// Caller supplies a closure (typically `() => realActivitiesForUser(...)`)
  /// so this widget stays decoupled from Firestore + Traccar.
  const PetActivityScreen.live({
    super.key,
    required Future<List<DailyActivity>> Function() loader,
    this.initialPetId,
  })  : _staticPets = null,
        _loader = loader;

  @override
  State<PetActivityScreen> createState() => _PetActivityScreenState();
}

class _PetActivityScreenState extends State<PetActivityScreen> {
  /// null while loading; empty list = "no pets"; non-empty = render.
  List<DailyActivity>? _pets;

  /// Set when the live load failed and we fell back to demo pets.
  String? _fallbackBanner;

  String _petId = '';
  String _range = 'Día';

  @override
  void initState() {
    super.initState();
    final staticPets = widget._staticPets;
    if (staticPets != null) {
      _pets = staticPets;
      _petId = widget.initialPetId ??
          (staticPets.isNotEmpty ? staticPets.first.petId : '');
    } else {
      _petId = widget.initialPetId ?? '';
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final pets = await widget._loader!();
      if (!mounted) return;
      setState(() {
        _pets = pets;
        if (_petId.isEmpty && pets.isNotEmpty) _petId = pets.first.petId;
      });
    } catch (e, st) {
      debugPrint('[pet_activity_screen] load failed: $e\n$st');
      if (!mounted) return;
      final fallback = demoActivities();
      setState(() {
        _pets = fallback;
        _fallbackBanner =
            'No pudimos cargar tu actividad real. Mostrando ejemplo.';
        if (_petId.isEmpty && fallback.isNotEmpty) {
          _petId = fallback.first.petId;
        }
      });
    }
  }

  DailyActivity get _selected => _pets!.firstWhere(
        (p) => p.petId == _petId,
        orElse: () => _pets!.first,
      );

  @override
  Widget build(BuildContext context) {
    final pets = _pets;
    if (pets == null) return const _LoadingScaffold();
    if (pets.isEmpty) {
      return Scaffold(
        backgroundColor: PettiColors.cloud,
        body: const SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'No tienes mascotas todavía. Agrega una desde la pantalla principal.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }

    final pet = _selected;
    return Scaffold(
      backgroundColor: PettiColors.cloud,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const _TopBar(),
            if (_fallbackBanner != null) _FallbackBanner(text: _fallbackBanner!),
            const SizedBox(height: PettiSpacing.s1),
            _PetPicker(
              pets: pets,
              activeId: _petId,
              onPick: (id) => setState(() => _petId = id),
            ),
            const SizedBox(height: PettiSpacing.s2),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                    PettiSpacing.s4, 0, PettiSpacing.s4, PettiSpacing.s7),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _PetHeaderStrip(pet: pet),
                    if (pet.status == PetActivityStatus.offline)
                      _OfflineState(pet: pet)
                    else ...[
                      _RangeTabs(
                        value: _range,
                        onChange: (v) => setState(() => _range = v),
                      ),
                      const SizedBox(height: PettiSpacing.s4),
                      _HeroRingsCard(pet: pet),
                      const SizedBox(height: PettiSpacing.s3),
                      _StatTilesGrid(pet: pet),
                      const SizedBox(height: PettiSpacing.s3),
                      _WeeklyChartCard(pet: pet),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Loading + fallback-banner widgets — only used in the live-data path.
// =============================================================================

class _LoadingScaffold extends StatelessWidget {
  const _LoadingScaffold();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PettiColors.cloud,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const _TopBar(),
            const SizedBox(height: PettiSpacing.s5),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          PettiColors.midnight.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                    const SizedBox(height: PettiSpacing.s3),
                    Text(
                      'Cargando actividad…',
                      style: PettiText.bodySm()
                          .copyWith(color: PettiColors.fgDim),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FallbackBanner extends StatelessWidget {
  final String text;
  const _FallbackBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
          PettiSpacing.s4, 0, PettiSpacing.s4, PettiSpacing.s2),
      padding: const EdgeInsets.symmetric(
          horizontal: PettiSpacing.s3, vertical: PettiSpacing.s2),
      decoration: BoxDecoration(
        color: PettiColors.marigoldSoft,
        borderRadius: BorderRadius.circular(PettiRadii.md),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded,
              size: 16, color: PettiColors.marigoldDim),
          const SizedBox(width: PettiSpacing.s2),
          Expanded(
            child: Text(
              text,
              style: PettiText.bodySm().copyWith(
                fontSize: 12,
                color: PettiColors.marigoldDim,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Top bar — overline + bold heading + two icon buttons.
// =============================================================================

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          PettiSpacing.s5, PettiSpacing.s2, PettiSpacing.s5, PettiSpacing.s3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 2026-05-11: back button added — the screen previously had
          // no way to exit because the design never spec'd a way back.
          // Pops the route, which lands the user on whatever pushed this
          // (home screen for the AppBar entry, settings/onboarding for
          // any other entry).
          _RoundIconButton(
            icon: Icons.chevron_left_rounded,
            onTap: () => Navigator.maybePop(context),
          ),
          const SizedBox(width: PettiSpacing.s2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ACTIVIDAD',
                  style: PettiText.meta().copyWith(
                    color: PettiColors.fgDim,
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Mis mascotas',
                  style: PettiText.h2().copyWith(
                    fontSize: 24,
                    height: 1.0,
                    color: PettiColors.midnight,
                  ),
                ),
              ],
            ),
          ),
          _RoundIconButton(icon: Icons.calendar_today_rounded, onTap: () {}),
          const SizedBox(width: PettiSpacing.s2),
          _RoundIconButton(icon: Icons.more_horiz_rounded, onTap: () {}),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      radius: 22,
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: PettiColors.borderLight, width: 1),
        ),
        child: Icon(icon, size: 17, color: PettiColors.midnight),
      ),
    );
  }
}

// =============================================================================
// Pet picker — horizontal scroller of pet pills + an "add pet" tile.
// =============================================================================

class _PetPicker extends StatelessWidget {
  final List<DailyActivity> pets;
  final String activeId;
  final ValueChanged<String> onPick;
  const _PetPicker({
    required this.pets,
    required this.activeId,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: PettiSpacing.s4),
        itemCount: pets.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: PettiSpacing.s2),
        itemBuilder: (ctx, i) {
          if (i == pets.length) return const _AddPetTile();
          final pet = pets[i];
          return _PetPickerPill(
            pet: pet,
            selected: pet.petId == activeId,
            onTap: () => onPick(pet.petId),
          );
        },
      ),
    );
  }
}

class _PetPickerPill extends StatelessWidget {
  final DailyActivity pet;
  final bool selected;
  final VoidCallback onTap;
  const _PetPickerPill({
    required this.pet,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(PettiRadii.pill),
      child: AnimatedContainer(
        duration: PettiMotion.std,
        curve: PettiMotion.ease,
        padding: const EdgeInsets.fromLTRB(
            PettiSpacing.s2, PettiSpacing.s2, PettiSpacing.s3, PettiSpacing.s2),
        decoration: BoxDecoration(
          color: selected ? PettiColors.midnight : Colors.white,
          borderRadius: BorderRadius.circular(PettiRadii.pill),
          border: selected
              ? null
              : Border.all(color: PettiColors.borderLight, width: 1),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: PettiColors.midnight.withValues(alpha: 0.18),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PetCircle(pet: pet, size: 32),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  pet.name,
                  style: TextStyle(
                    fontFamily: 'Space Grotesk',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: selected ? PettiColors.cloud : PettiColors.midnight,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  pet.online ? '● en vivo' : '○ desconectado',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    color: selected
                        ? PettiColors.fgOnDarkDim
                        : PettiColors.fgDim,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AddPetTile extends StatelessWidget {
  const _AddPetTile();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: PettiColors.n300,
          width: 1.5,
          strokeAlign: BorderSide.strokeAlignInside,
        ),
      ),
      child: Icon(Icons.add_rounded, size: 20, color: PettiColors.fgDim),
    );
  }
}

// =============================================================================
// PetCircle — gradient-filled avatar with online dot.
// =============================================================================

class _PetCircle extends StatelessWidget {
  final DailyActivity pet;
  final double size;
  const _PetCircle({required this.pet, this.size = 48});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [pet.avatarTop, pet.avatarBottom],
              ),
              boxShadow: [
                BoxShadow(
                  color: PettiColors.midnight.withValues(alpha: 0.10),
                  offset: const Offset(0, -2),
                  blurRadius: 6,
                  spreadRadius: -2,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              pet.name.substring(0, 1).toUpperCase(),
              style: TextStyle(
                fontFamily: 'Space Grotesk',
                fontSize: size * 0.4,
                fontWeight: FontWeight.w700,
                color: PettiColors.midnight,
                letterSpacing: -0.2,
              ),
            ),
          ),
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: size * 0.28,
              height: size * 0.28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: pet.online ? PettiColors.sabana : PettiColors.trail,
                border: Border.all(color: PettiColors.cloud, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Pet header strip — selected pet's avatar + name + battery + Mapa button.
// =============================================================================

class _PetHeaderStrip extends StatelessWidget {
  final DailyActivity pet;
  const _PetHeaderStrip({required this.pet});

  @override
  Widget build(BuildContext context) {
    final batteryColor =
        pet.batteryPercent > 25 ? PettiColors.fg : PettiColors.duskRose;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          4, PettiSpacing.s3, 0, PettiSpacing.s4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _PetCircle(pet: pet, size: 42),
          const SizedBox(width: PettiSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: Text(
                        pet.name,
                        style: PettiText.h3().copyWith(
                          fontSize: 18,
                          color: PettiColors.midnight,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: PettiSpacing.s2),
                    Flexible(
                      child: Text(
                        pet.kind,
                        style: PettiText.bodySm().copyWith(
                          fontSize: 12,
                          color: PettiColors.fgDim,
                          height: 1.3,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 1),
                Row(
                  children: [
                    Icon(Icons.battery_4_bar_rounded,
                        size: 13, color: batteryColor),
                    const SizedBox(width: 4),
                    Text(
                      '${pet.batteryPercent}%',
                      style: PettiText.bodySm().copyWith(
                        fontSize: 12,
                        color: batteryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text('·',
                        style: PettiText.bodySm()
                            .copyWith(color: PettiColors.fgDim)),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        pet.lastSyncRelative,
                        style: PettiText.bodySm().copyWith(
                          fontSize: 12,
                          color: PettiColors.fgDim,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: PettiSpacing.s2),
          _MapPill(onTap: () => Navigator.pop(context)),
        ],
      ),
    );
  }
}

class _MapPill extends StatelessWidget {
  final VoidCallback onTap;
  const _MapPill({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(PettiRadii.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: PettiSpacing.s3, vertical: 7),
        decoration: BoxDecoration(
          color: PettiColors.marigoldSoft,
          borderRadius: BorderRadius.circular(PettiRadii.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_on_rounded,
                size: 13, color: PettiColors.marigoldDim),
            const SizedBox(width: 5),
            Text(
              'Mapa',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: PettiColors.marigoldDim,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Range tabs — segmented control.
// =============================================================================

class _RangeTabs extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChange;
  const _RangeTabs({required this.value, required this.onChange});

  @override
  Widget build(BuildContext context) {
    const opts = ['Día', 'Semana', 'Mes', 'Año'];
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: PettiColors.sand,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: opts.map((o) {
          final sel = o == value;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChange(o),
              child: AnimatedContainer(
                duration: PettiMotion.micro,
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: sel ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: sel
                      ? [
                          BoxShadow(
                            color: PettiColors.midnight.withValues(alpha: 0.08),
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  o,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12.5,
                    fontWeight: sel ? FontWeight.w600 : FontWeight.w500,
                    color: sel ? PettiColors.midnight : PettiColors.fg,
                    letterSpacing: -0.05,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// =============================================================================
// Hero rings card — three concentric activity rings + legend.
// =============================================================================

class _HeroRingsCard extends StatelessWidget {
  final DailyActivity pet;
  const _HeroRingsCard({required this.pet});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(PettiSpacing.s4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: PettiColors.borderLight, width: 1),
        boxShadow: [
          BoxShadow(
            color: PettiColors.midnight.withValues(alpha: 0.04),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
          BoxShadow(
            color: PettiColors.midnight.withValues(alpha: 0.05),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _ActivityRings(pet: pet, size: 148),
          const SizedBox(width: PettiSpacing.s4),
          Expanded(child: _RingLegend(pet: pet)),
        ],
      ),
    );
  }
}

class _ActivityRings extends StatelessWidget {
  final DailyActivity pet;
  final double size;
  const _ActivityRings({required this.pet, this.size = 180});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _ActivityRingsPainter(
              progress: [
                _safePct(pet.distanceKm, pet.distanceGoalKm),
                _safePct(pet.activeMinutes.toDouble(),
                    pet.activeGoalMinutes.toDouble()),
                _safePct(pet.intensityMinutes.toDouble(),
                    pet.intensityGoalMinutes.toDouble()),
              ],
              colors: const [
                PettiColors.marigold,
                PettiColors.sabana,
                PettiColors.duskRose,
              ],
              dimColors: [
                PettiColors.marigoldSoft,
                PettiColors.sabanaSoft,
                PettiColors.duskSoft,
              ],
              strokeWidth: 10,
            ),
          ),
          // Center label
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'HOY',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: PettiColors.fgDim,
                  letterSpacing: 1.6,
                ),
              ),
              const SizedBox(height: 2),
              Text.rich(
                TextSpan(
                  text: pet.distanceKm.toStringAsFixed(1),
                  style: TextStyle(
                    fontFamily: 'Space Grotesk',
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: PettiColors.midnight,
                    letterSpacing: -0.6,
                    height: 1.0,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                  children: [
                    TextSpan(
                      text: ' km',
                      style: TextStyle(
                        fontSize: 14,
                        color: PettiColors.fgDim,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'de ${pet.distanceGoalKm.toStringAsFixed(0)} km',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  color: PettiColors.fgDim,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static double _safePct(double val, double goal) =>
      goal <= 0 ? 0 : math.min(1.0, val / goal);
}

class _ActivityRingsPainter extends CustomPainter {
  final List<double> progress;
  final List<Color> colors;
  final List<Color> dimColors;
  final double strokeWidth;

  _ActivityRingsPainter({
    required this.progress,
    required this.colors,
    required this.dimColors,
    required this.strokeWidth,
  }) : assert(progress.length == colors.length);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    // 3 rings — outermost = 70, then 56, then 42 (matches design)
    const radii = [70.0, 56.0, 42.0];
    for (var i = 0; i < progress.length; i++) {
      final r = radii[i];
      final dimPaint = Paint()
        ..color = dimColors[i]
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;
      canvas.drawCircle(c, r, dimPaint);
      final filledPaint = Paint()
        ..color = colors[i]
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = strokeWidth;
      // Start from 12 o'clock, sweep clockwise.
      final sweep = 2 * math.pi * progress[i];
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        -math.pi / 2,
        sweep,
        false,
        filledPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ActivityRingsPainter old) =>
      old.progress != progress ||
      old.colors != colors ||
      old.dimColors != dimColors ||
      old.strokeWidth != strokeWidth;
}

class _RingLegend extends StatelessWidget {
  final DailyActivity pet;
  const _RingLegend({required this.pet});

  @override
  Widget build(BuildContext context) {
    final items = [
      _LegendItem(
        color: PettiColors.marigold,
        label: 'DISTANCIA',
        value: '${pet.distanceKm.toStringAsFixed(1)} km',
        goal: '${pet.distanceGoalKm.toStringAsFixed(0)} km',
      ),
      _LegendItem(
        color: PettiColors.sabana,
        label: 'ACTIVO',
        value: '${pet.activeMinutes} min',
        goal: '${pet.activeGoalMinutes} min',
      ),
      _LegendItem(
        color: PettiColors.duskRose,
        label: 'INTENSIDAD',
        value: '${pet.intensityMinutes} min',
        goal: '${pet.intensityGoalMinutes} min',
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: PettiSpacing.s3),
          items[i],
        ],
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final String value;
  final String goal;
  const _LegendItem({
    required this.color,
    required this.label,
    required this.value,
    required this.goal,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: PettiColors.fgDim,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text.rich(
          TextSpan(
            text: value,
            style: TextStyle(
              fontFamily: 'Space Grotesk',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: PettiColors.midnight,
              letterSpacing: -0.4,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            children: [
              TextSpan(
                text: '  / $goal',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: PettiColors.fgDim,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Stat tiles — 2x2 grid of quick metrics.
// =============================================================================

class _StatTilesGrid extends StatelessWidget {
  final DailyActivity pet;
  const _StatTilesGrid({required this.pet});

  @override
  Widget build(BuildContext context) {
    final stats = <_StatTileSpec>[
      _StatTileSpec(
        icon: Icons.pets_rounded,
        label: 'PASOS',
        value: _formatThousands(pet.steps),
        unit: null,
        accent: PettiColors.marigoldDim,
        iconBg: PettiColors.marigoldSoft,
      ),
      _StatTileSpec(
        icon: Icons.speed_rounded,
        label: 'RITMO PROM.',
        value: ActivityCalculator.formatPace(pet.averagePaceMinPerKm),
        unit: '/km',
        accent: PettiColors.sabana,
        iconBg: PettiColors.sabanaSoft,
      ),
      _StatTileSpec(
        icon: Icons.bolt_rounded,
        label: 'VEL. MÁX.',
        value: pet.maxSpeedKmh.toStringAsFixed(1),
        unit: 'km/h',
        accent: PettiColors.duskRose,
        iconBg: PettiColors.duskSoft,
      ),
      _StatTileSpec(
        icon: Icons.local_fire_department_rounded,
        label: 'CALORÍAS',
        value: pet.caloriesKcal.toString(),
        unit: 'kcal',
        accent: PettiColors.cafe,
        iconBg: PettiColors.cafeSoft,
      ),
    ];
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.45,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: stats.map((s) => _StatTile(spec: s)).toList(),
    );
  }

  static String _formatThousands(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

class _StatTileSpec {
  final IconData icon;
  final String label;
  final String value;
  final String? unit;
  final Color accent;
  final Color iconBg;
  const _StatTileSpec({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.accent,
    required this.iconBg,
  });
}

class _StatTile extends StatelessWidget {
  final _StatTileSpec spec;
  const _StatTile({required this.spec});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PettiColors.borderLight, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: spec.iconBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(spec.icon, size: 16, color: spec.accent),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                spec.label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: PettiColors.fgDim,
                  letterSpacing: 0.7,
                ),
              ),
              const SizedBox(height: 4),
              Text.rich(
                TextSpan(
                  text: spec.value,
                  style: TextStyle(
                    fontFamily: 'Space Grotesk',
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: PettiColors.midnight,
                    letterSpacing: -0.4,
                    height: 1.05,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                  children: [
                    if (spec.unit != null)
                      TextSpan(
                        text: ' ${spec.unit}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: PettiColors.fgDim,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Weekly chart — bar chart with goal line, today highlighted.
// =============================================================================

class _WeeklyChartCard extends StatelessWidget {
  final DailyActivity pet;
  const _WeeklyChartCard({required this.pet});

  @override
  Widget build(BuildContext context) {
    final weekTotal =
        pet.weeklyDistanceKm.fold<double>(0, (a, b) => a + b);
    return Container(
      padding: const EdgeInsets.all(PettiSpacing.s4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: PettiColors.borderLight, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ESTA SEMANA',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: PettiColors.fgDim,
                        letterSpacing: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${weekTotal.toStringAsFixed(1)} km',
                      style: TextStyle(
                        fontFamily: 'Space Grotesk',
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: PettiColors.midnight,
                        letterSpacing: -0.6,
                        height: 1.05,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              // Trend chip — placeholder; real trend is a follow-up.
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: PettiColors.sabanaSoft,
                  borderRadius: BorderRadius.circular(PettiRadii.pill),
                ),
                child: Text(
                  '+18% vs sem. anterior',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: PettiColors.sabana,
                    letterSpacing: -0.05,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: PettiSpacing.s3),
          SizedBox(height: 142, child: _WeekBars(pet: pet)),
        ],
      ),
    );
  }
}

class _WeekBars extends StatelessWidget {
  final DailyActivity pet;
  const _WeekBars({required this.pet});

  @override
  Widget build(BuildContext context) {
    final week = pet.weeklyDistanceKm;
    final maxValue =
        math.max(week.reduce(math.max), pet.distanceGoalKm) * 1.05;
    final todayIdx = week.length - 1; // by convention: last entry is today
    final goalY = pet.distanceGoalKm / maxValue; // 0..1 inside the bar area
    return LayoutBuilder(
      builder: (ctx, c) {
        const barAreaHeight = 110.0;
        return Stack(
          children: [
            // Goal dashed line
            Positioned(
              left: 0,
              right: 0,
              bottom: (goalY * barAreaHeight) + 18,
              child: CustomPaint(
                painter: _DashedLinePainter(color: PettiColors.n300),
                size: const Size.fromHeight(1.5),
                child: Align(
                  alignment: Alignment.topRight,
                  child: Container(
                    margin: const EdgeInsets.only(top: -16),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    color: PettiColors.cloud,
                    child: Text(
                      'meta ${pet.distanceGoalKm.toStringAsFixed(0)} km',
                      style: TextStyle(
                        fontFamily: 'Space Grotesk',
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: PettiColors.fgDim,
                        letterSpacing: -0.05,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Bars
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < week.length; i++) ...[
                  Expanded(
                    child: _DayBar(
                      value: week[i],
                      maxValue: maxValue,
                      barAreaHeight: barAreaHeight,
                      isToday: i == todayIdx,
                      hitGoal: week[i] >= pet.distanceGoalKm,
                      label: pet.weeklyDayLabels[i],
                    ),
                  ),
                  if (i < week.length - 1) const SizedBox(width: 8),
                ],
              ],
            ),
          ],
        );
      },
    );
  }
}

class _DayBar extends StatelessWidget {
  final double value;
  final double maxValue;
  final double barAreaHeight;
  final bool isToday;
  final bool hitGoal;
  final String label;
  const _DayBar({
    required this.value,
    required this.maxValue,
    required this.barAreaHeight,
    required this.isToday,
    required this.hitGoal,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final raw = (value / maxValue) * barAreaHeight;
    final h = math.max(raw, value == 0 ? 4.0 : 8.0);

    final gradient = value == 0
        ? const LinearGradient(
            colors: [PettiColors.n200, PettiColors.n200],
          )
        : hitGoal
            ? const LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [PettiColors.sabana, Color(0xFF4A8A78)],
              )
            : isToday
                ? const LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [PettiColors.marigoldDim, PettiColors.marigold],
                  )
                : const LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [PettiColors.n300, PettiColors.n400],
                  );

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        SizedBox(
          height: barAreaHeight,
          child: Stack(
            alignment: Alignment.bottomCenter,
            clipBehavior: Clip.none,
            children: [
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 24),
                height: h,
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: isToday
                      ? [
                          BoxShadow(
                            color: PettiColors.marigold.withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
              ),
              if (isToday)
                Positioned(
                  bottom: h + 4,
                  child: Text(
                    value.toStringAsFixed(1),
                    style: TextStyle(
                      fontFamily: 'Space Grotesk',
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: PettiColors.midnight,
                      letterSpacing: -0.1,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
            color: isToday ? PettiColors.midnight : PettiColors.fgDim,
          ),
        ),
      ],
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color color;
  _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5;
    const dashWidth = 5.0;
    const gapWidth = 4.0;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(math.min(x + dashWidth, size.width), 0),
        paint,
      );
      x += dashWidth + gapWidth;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter old) => old.color != color;
}

// =============================================================================
// Offline empty state.
// =============================================================================

class _OfflineState extends StatelessWidget {
  final DailyActivity pet;
  const _OfflineState({required this.pet});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: PettiColors.borderLight, width: 1),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: PettiColors.trail.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.wifi_off_rounded,
                size: 26, color: PettiColors.trail),
          ),
          const SizedBox(height: 14),
          Text(
            '${pet.name} está sin conexión',
            style: PettiText.h4().copyWith(fontSize: 17),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Última sincronización ${pet.lastSyncRelative}. Su batería estaba en ${pet.batteryPercent}%.',
            style: PettiText.bodySm().copyWith(
              fontSize: 13,
              color: PettiColors.fgDim,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: PettiColors.midnight,
              foregroundColor: PettiColors.cloud,
              padding: const EdgeInsets.symmetric(
                  horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              textStyle: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                fontSize: 13,
                letterSpacing: -0.05,
              ),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('Ver última ubicación'),
          ),
        ],
      ),
    );
  }
}
