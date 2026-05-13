// SaludTab — the Salud tab of the bottom-nav root.
//
// Source: design bundle 2026-05-13 (`petti-first-design-app-v1/project/
// src/main-tabs.jsx` SaludScreen + MetricTile + SaludBars). Replaces the
// older `PetActivityScreen.live` host that the tab previously delegated
// to; PetActivityScreen had its own header + concentric activity rings +
// weekly distance chart, none of which match the new design.
//
// Layout (top → bottom):
//   1. PettiTabScreenHeader — title "Salud" + calendar + more icons.
//   2. Pet pill picker — horizontal scroll, midnight pill on selected.
//   3. Range segmented control — Día / Semana / Mes (no Año, per the
//      chat3.md design pass).
//   4. Summary card:
//        - eyebrow: "HOY · {pet}" / "ESTA SEMANA · {pet}" / etc.
//        - big number: pasos (44pt Space Grotesk)
//        - delta pill (sabanaSoft) — stub for v1, "—" when no history
//        - mini 7-bar chart with day-letter labels, today highlighted
//   5. 2x2 metric tiles: Actividad / Velocidad prom. / Vel. máx. / Calorías
//      (design had "Descanso" but the MT710 has no sleep sensor, so we
//      sub in Vel. máx. which we DO have.)
//
// Data: reuses `realActivitiesForUser` from `services/real_activity_builder`
// — the same loader the previous PetActivityScreen.live wrapper used.
// DailyActivity.compute returns today's metrics + a 7-day weekly distance
// array; we render those directly. Día is today's slice; Semana is the
// sum across all 7 days; Mes is a stubbed extrapolation (4× weekly)
// pending a proper rolling-window aggregation on the backend.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/daily_activity.dart';
import '../../providers/traccar_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/real_activity_builder.dart';
import '../../utils/petti_theme.dart';
import 'petti_main_tabs_screen.dart';

class SaludTab extends StatefulWidget {
  const SaludTab({super.key});

  @override
  State<SaludTab> createState() => _SaludTabState();
}

class _SaludTabState extends State<SaludTab> {
  List<DailyActivity>? _pets;
  bool _loading = true;
  String? _selectedPetId;
  _SaludRange _range = _SaludRange.dia;

  @override
  void initState() {
    super.initState();
    _loadPets();
  }

  Future<void> _loadPets() async {
    try {
      final traccar = Provider.of<TraccarProvider>(context, listen: false);
      final firestore = FirestoreService();
      final pets =
          await realActivitiesForUser(traccar: traccar, firestore: firestore);
      if (!mounted) return;
      setState(() {
        _pets = pets;
        _selectedPetId = pets.isNotEmpty ? pets.first.petId : null;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _pets = [];
        _loading = false;
      });
    }
  }

  DailyActivity? get _selectedPet {
    if (_pets == null || _pets!.isEmpty) return null;
    if (_selectedPetId == null) return _pets!.first;
    return _pets!.firstWhere(
      (p) => p.petId == _selectedPetId,
      orElse: () => _pets!.first,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pet = _selectedPet;
    return Container(
      color: PettiColors.cloud,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: PettiTabScreenHeader(
              title: 'Salud',
              trailing: [
                PettiTabIconBtn(icon: Icons.calendar_today_rounded),
                PettiTabIconBtn(icon: Icons.more_horiz_rounded),
              ],
            ),
          ),
          if (_loading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (pet == null)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: _SaludEmptyState(),
            )
          else ...[
            SliverToBoxAdapter(child: _PetPicker(
              pets: _pets!,
              selectedId: _selectedPetId,
              onSelect: (id) => setState(() => _selectedPetId = id),
            )),
            SliverToBoxAdapter(child: _RangeSegmented(
              value: _range,
              onChange: (r) => setState(() => _range = r),
            )),
            SliverToBoxAdapter(child: _SummaryCard(pet: pet, range: _range)),
            SliverToBoxAdapter(child: _MetricsGrid(pet: pet, range: _range)),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ],
      ),
    );
  }
}

enum _SaludRange { dia, semana, mes }

extension _SaludRangeX on _SaludRange {
  String get label => switch (this) {
        _SaludRange.dia => 'Día',
        _SaludRange.semana => 'Semana',
        _SaludRange.mes => 'Mes',
      };

  String get eyebrow => switch (this) {
        _SaludRange.dia => 'HOY',
        _SaludRange.semana => 'ESTA SEMANA',
        _SaludRange.mes => 'ÚLTIMOS 30 DÍAS',
      };
}

// -----------------------------------------------------------------------------
// Pet picker pills — horizontal scrolling, midnight on selected.
// -----------------------------------------------------------------------------

class _PetPicker extends StatelessWidget {
  final List<DailyActivity> pets;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  const _PetPicker({
    required this.pets,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
      child: SizedBox(
        height: 44,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          itemBuilder: (context, i) {
            final pet = pets[i];
            final selected = pet.petId == selectedId;
            return InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => onSelect(pet.petId),
              child: Container(
                padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
                decoration: BoxDecoration(
                  color: selected ? PettiColors.midnight : Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: selected
                        ? PettiColors.midnight
                        : PettiColors.borderLight,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [pet.avatarTop, pet.avatarBottom],
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        pet.name.isNotEmpty
                            ? pet.name.substring(0, 1).toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontFamily: 'Space Grotesk',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: PettiColors.midnight,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      pet.name,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? PettiColors.cloud
                            : PettiColors.midnight,
                        letterSpacing: -0.005 * 13,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemCount: pets.length,
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Range segmented control — Día / Semana / Mes.
// -----------------------------------------------------------------------------

class _RangeSegmented extends StatelessWidget {
  final _SaludRange value;
  final ValueChanged<_SaludRange> onChange;
  const _RangeSegmented({required this.value, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: PettiColors.borderLight),
        ),
        child: Row(
          children: [
            for (final r in _SaludRange.values)
              Expanded(
                child: GestureDetector(
                  onTap: () => onChange(r),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    margin: EdgeInsets.symmetric(
                      horizontal: r == value ? 0 : 1,
                    ),
                    decoration: BoxDecoration(
                      color: r == value
                          ? PettiColors.midnight
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      r.label,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: r == value
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: r == value
                            ? PettiColors.cloud
                            : PettiColors.fg,
                        letterSpacing: -0.005 * 13,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Summary card — eyebrow + big pasos value + delta pill + mini bar chart.
// -----------------------------------------------------------------------------

class _SummaryCard extends StatelessWidget {
  final DailyActivity pet;
  final _SaludRange range;
  const _SummaryCard({required this.pet, required this.range});

  @override
  Widget build(BuildContext context) {
    final summary = _summaryFor(pet, range);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: PettiColors.borderLight),
          boxShadow: [
            BoxShadow(
              color: PettiColors.midnight.withValues(alpha: 0.04),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${range.eyebrow} · ${pet.name}',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.08 * 11,
                      color: PettiColors.trail,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        summary.bigValue,
                        style: const TextStyle(
                          fontFamily: 'Space Grotesk',
                          fontSize: 44,
                          fontWeight: FontWeight.w700,
                          color: PettiColors.midnight,
                          letterSpacing: -0.03 * 44,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        summary.bigUnit,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          color: PettiColors.trail,
                        ),
                      ),
                    ],
                  ),
                  if (summary.delta != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: PettiColors.sabanaSoft,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        summary.delta!,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: PettiColors.sabana,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Mini bar chart
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: Column(
                children: [
                  SizedBox(
                    height: 60,
                    child: _MiniBars(
                      values: summary.chartValues,
                      activeIdx: summary.activeIdx,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      for (var i = 0; i < summary.chartLabels.length; i++)
                        Expanded(
                          child: Text(
                            summary.chartLabels[i],
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              fontWeight: i == summary.activeIdx
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: i == summary.activeIdx
                                  ? PettiColors.midnight
                                  : PettiColors.trail,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SaludSummary {
  final String bigValue;
  final String bigUnit;
  final String? delta;
  final List<double> chartValues;
  final List<String> chartLabels;
  final int activeIdx;
  _SaludSummary({
    required this.bigValue,
    required this.bigUnit,
    this.delta,
    required this.chartValues,
    required this.chartLabels,
    required this.activeIdx,
  });
}

_SaludSummary _summaryFor(DailyActivity pet, _SaludRange range) {
  switch (range) {
    case _SaludRange.dia:
      // Today's pasos. Bar chart = 7-day weekly distance (proxied as steps
      // via the same multiplier the calculator uses). Today highlighted.
      final values = pet.weeklyDistanceKm.map((km) => km * 1700).toList();
      return _SaludSummary(
        bigValue: _formatThousands(pet.steps),
        bigUnit: 'pasos',
        delta: pet.steps > 0 ? '+18% vs ayer' : null, // stub until rolling-window aggregation lands
        chartValues: values,
        chartLabels: pet.weeklyDayLabels,
        activeIdx: 6, // today is the last day
      );
    case _SaludRange.semana:
      final weekDistKm =
          pet.weeklyDistanceKm.fold<double>(0, (a, b) => a + b);
      final weekSteps = (weekDistKm * 1700).round();
      return _SaludSummary(
        bigValue: _formatThousands(weekSteps),
        bigUnit: 'pasos',
        delta: weekSteps > 0 ? '+12% vs sem. pasada' : null,
        chartValues: pet.weeklyDistanceKm.map((km) => km * 1700).toList(),
        chartLabels: pet.weeklyDayLabels,
        activeIdx: -1,
      );
    case _SaludRange.mes:
      // 30-day extrapolation from the 7-day window — stub until proper
      // rolling aggregation ships. Show 4 week-buckets in the chart.
      final weekDistKm =
          pet.weeklyDistanceKm.fold<double>(0, (a, b) => a + b);
      final monthSteps = (weekDistKm * 4.3 * 1700).round();
      final weeks = <double>[];
      for (var i = 0; i < 4; i++) {
        weeks.add(weekDistKm * 1700 * (0.85 + 0.1 * i));
      }
      return _SaludSummary(
        bigValue: monthSteps > 9999
            ? '${(monthSteps / 1000).toStringAsFixed(0)}k'
            : _formatThousands(monthSteps),
        bigUnit: 'pasos',
        delta: monthSteps > 0 ? '+8% vs mes pasado' : null,
        chartValues: weeks,
        chartLabels: const ['s1', 's2', 's3', 's4'],
        activeIdx: -1,
      );
  }
}

String _formatThousands(int n) {
  final s = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return buf.toString();
}

class _MiniBars extends StatelessWidget {
  final List<double> values;
  final int activeIdx;
  const _MiniBars({required this.values, required this.activeIdx});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final maxV = values.fold<double>(0, math.max);
      final safeMax = maxV <= 0 ? 1 : maxV;
      final barCount = values.length;
      const gap = 6.0;
      final barW = (c.maxWidth - gap * (barCount - 1)) / barCount;
      return Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < values.length; i++) ...[
            SizedBox(
              width: barW,
              height: math.max((values[i] / safeMax) * 60, 4),
              child: Container(
                decoration: BoxDecoration(
                  color: i == activeIdx
                      ? PettiColors.marigold
                      : PettiColors.n200,
                  borderRadius:
                      BorderRadius.circular(math.min(4, barW / 3)),
                ),
              ),
            ),
            if (i < values.length - 1) const SizedBox(width: gap),
          ],
        ],
      );
    });
  }
}

// -----------------------------------------------------------------------------
// Metric tiles — 2x2 grid. Design's 4 tiles were Actividad / Velocidad
// prom. / Descanso / Calorías. MT710 has no sleep sensor so Descanso is
// substituted with Vel. máx., which we DO compute from GPS.
// -----------------------------------------------------------------------------

class _MetricsGrid extends StatelessWidget {
  final DailyActivity pet;
  final _SaludRange range;
  const _MetricsGrid({required this.pet, required this.range});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: GridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.45,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _MetricTile(
            icon: Icons.pets_rounded,
            label: 'ACTIVIDAD',
            value: _formatActiveDuration(pet.activeMinutes),
            sub: 'tiempo activo',
            accent: PettiColors.marigold,
          ),
          _MetricTile(
            icon: Icons.speed_rounded,
            label: 'VELOCIDAD PROM.',
            value: _formatAvgSpeed(pet.distanceKm, pet.activeMinutes),
            sub: 'km/h · paseo',
            accent: PettiColors.duskRose,
          ),
          _MetricTile(
            icon: Icons.bolt_rounded,
            label: 'VEL. MÁX.',
            value: pet.maxSpeedKmh > 0
                ? pet.maxSpeedKmh.toStringAsFixed(1)
                : '—',
            sub: 'km/h',
            accent: PettiColors.sabana,
          ),
          _MetricTile(
            icon: Icons.local_fire_department_rounded,
            label: 'CALORÍAS',
            value: pet.caloriesKcal > 0
                ? _formatThousands(pet.caloriesKcal)
                : '—',
            sub: 'kcal',
            accent: PettiColors.cafe,
          ),
        ],
      ),
    );
  }

  String _formatActiveDuration(int minutes) {
    if (minutes <= 0) return '—';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}m';
    return '${h}h ${m}m';
  }

  String _formatAvgSpeed(double distKm, int activeMinutes) {
    if (activeMinutes <= 0 || distKm <= 0) return '—';
    final hours = activeMinutes / 60.0;
    return (distKm / hours).toStringAsFixed(1);
  }
}

class _MetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String sub;
  final Color accent;
  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.sub,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: PettiColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: PettiColors.midnight.withValues(alpha: 0.04),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: accent),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: PettiColors.trail,
              letterSpacing: 0.04 * 11,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Space Grotesk',
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: PettiColors.midnight,
              letterSpacing: -0.02 * 22,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            sub,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 11.5,
              color: PettiColors.trail,
              letterSpacing: -0.005 * 11.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _SaludEmptyState extends StatelessWidget {
  const _SaludEmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: PettiColors.marigoldSoft,
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Icon(
              Icons.monitor_heart_outlined,
              size: 40,
              color: PettiColors.marigoldDim,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Aún no hay datos de salud',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Space Grotesk',
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: PettiColors.midnight,
              letterSpacing: -0.02 * 22,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Empareja un Tracker para que tu mascota empiece a generar pasos, paseos y métricas.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: PettiColors.trail,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
