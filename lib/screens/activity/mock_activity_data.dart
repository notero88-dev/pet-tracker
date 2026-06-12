// Mock activity data for the dashboard's v1 launch.
//
// The dashboard widgets (PetActivityScreen / ActivityRings / WeekChart) only
// know how to render a [DailyActivity]. Producing one from real Traccar
// position aggregation is a separate task — this file is the bridge that
// keeps the UI runnable today.
//
// Two paths:
//
//   - `mockActivitiesForDevices(devices)` takes the user's real Traccar
//     devices and synthesizes mock-but-plausible activity per pet. The
//     pet names + IMEIs are real; the metric numbers are made up.
//
//   - `demoActivities()` returns the 3 fictional pets from the design
//     bundle (Canela / Pipo / Luna) when the user has no devices yet —
//     so they can still see the dashboard and judge the UI.
//
// Delete this file once `lib/services/activity_calculator.dart` is wired
// to a real positions-by-day fetcher.

import 'package:flutter/material.dart';

import '../../models/daily_activity.dart';
import '../../models/device.dart';
import '../../services/activity_calculator.dart';
import 'pet_avatar_palette.dart';

/// Designed weekday labels — Monday-first per Latin-American convention.
const List<String> _weekdayLabels = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

/// The 3 demo pets from the design bundle (`pets-activity.jsx` PETS array).
/// Used as a fallback when the user has no real devices yet.
List<DailyActivity> demoActivities() {
  return [
    DailyActivity.mock(
      petId: 'canela',
      name: 'Canela',
      kind: 'Mestiza · 4 años',
      size: PetSize.dogMedium,
      avatarTop: const Color(0xFFF4D9A8),
      avatarBottom: const Color(0xFFE8A33D),
      online: true,
      batteryPercent: 80,
      lastSyncRelative: 'hace 2 min',
      status: PetActivityStatus.safe,
      distanceKm: 3.2,
      activeMinutes: 64,
      intensityMinutes: 42,
      maxSpeedKmh: 14.2,
      averagePaceMinPerKm: 8 + 12 / 60,
      weeklyDistanceKm: const [2.4, 4.1, 3.8, 1.9, 5.3, 6.7, 3.2],
      weeklyDayLabels: _weekdayLabels,
      lastWalkPlace: 'Parque El Virrey',
      lastWalkRelative: 'hace 1h',
    ),
    DailyActivity.mock(
      petId: 'pipo',
      name: 'Pipo',
      kind: 'Criollo · 7 años',
      size: PetSize.dogSmall,
      avatarTop: const Color(0xFFD9DEE6),
      avatarBottom: const Color(0xFF5F6876),
      online: true,
      batteryPercent: 54,
      lastSyncRelative: 'hace 14 min',
      status: PetActivityStatus.home,
      distanceKm: 0.6,
      activeMinutes: 18,
      intensityMinutes: 8,
      maxSpeedKmh: 6.8,
      averagePaceMinPerKm: null,
      weeklyDistanceKm: const [0.4, 0.9, 0.3, 0.7, 0.5, 1.1, 0.6],
      weeklyDayLabels: _weekdayLabels,
      lastWalkPlace: 'Casa',
      lastWalkRelative: 'hace 30 min',
    ),
    DailyActivity.mock(
      petId: 'luna',
      name: 'Luna',
      kind: 'Border collie · 2 años',
      size: PetSize.dogLarge,
      avatarTop: const Color(0xFFF2DCD4),
      avatarBottom: const Color(0xFFC97A6E),
      online: false,
      batteryPercent: 12,
      lastSyncRelative: 'hace 4 h',
      status: PetActivityStatus.offline,
      distanceKm: 0,
      activeMinutes: 0,
      intensityMinutes: 0,
      maxSpeedKmh: 18.6,
      averagePaceMinPerKm: 7 + 4 / 60,
      weeklyDistanceKm: const [7.2, 5.8, 6.4, 4.9, 8.3, 0, 0],
      weeklyDayLabels: _weekdayLabels,
      lastWalkPlace: 'Cerros Orientales',
      lastWalkRelative: 'ayer',
    ),
  ];
}

/// For each real Traccar device, produce a [DailyActivity] with the pet's
/// real name + a deterministic avatar gradient + plausible-but-mock
/// activity numbers. This is the bridge until real Traccar aggregation is
/// wired in.
List<DailyActivity> mockActivitiesForDevices(List<Device> devices) {
  if (devices.isEmpty) return demoActivities();

  final list = <DailyActivity>[];
  for (var i = 0; i < devices.length; i++) {
    final d = devices[i];
    final colors = petAvatarFor(d.name);
    final spec = _mockSeed(i, d.name);
    list.add(DailyActivity.mock(
      petId: d.uniqueId,
      name: d.name,
      kind: spec.kind,
      size: spec.size,
      avatarTop: colors[0],
      avatarBottom: colors[1],
      online: d.status == 'active',
      batteryPercent: spec.battery,
      lastSyncRelative: spec.lastSync,
      status: d.status == 'active'
          ? PetActivityStatus.safe
          : PetActivityStatus.offline,
      distanceKm: spec.distanceKm,
      activeMinutes: spec.activeMin,
      intensityMinutes: spec.intensityMin,
      maxSpeedKmh: spec.maxKmh,
      averagePaceMinPerKm: spec.paceMinPerKm,
      weeklyDistanceKm: spec.weekly,
      weeklyDayLabels: _weekdayLabels,
      lastWalkPlace: spec.lastWalkPlace,
      lastWalkRelative: spec.lastWalkRelative,
    ));
  }
  return list;
}

class _MockSeed {
  final String kind;
  final PetSize size;
  final int battery;
  final String lastSync;
  final double distanceKm;
  final int activeMin;
  final int intensityMin;
  final double maxKmh;
  final double? paceMinPerKm;
  final List<double> weekly;
  final String lastWalkPlace;
  final String lastWalkRelative;
  const _MockSeed({
    required this.kind,
    required this.size,
    required this.battery,
    required this.lastSync,
    required this.distanceKm,
    required this.activeMin,
    required this.intensityMin,
    required this.maxKmh,
    required this.paceMinPerKm,
    required this.weekly,
    required this.lastWalkPlace,
    required this.lastWalkRelative,
  });
}

/// Three rotating mock seeds so multi-pet households get a non-uniform feel.
_MockSeed _mockSeed(int index, String name) {
  final seeds = <_MockSeed>[
    const _MockSeed(
      kind: 'Mascota · activa',
      size: PetSize.dogMedium,
      battery: 80,
      lastSync: 'hace 2 min',
      distanceKm: 3.2,
      activeMin: 64,
      intensityMin: 42,
      maxKmh: 14.2,
      paceMinPerKm: 8.2,
      weekly: [2.4, 4.1, 3.8, 1.9, 5.3, 6.7, 3.2],
      lastWalkPlace: 'Parque El Virrey',
      lastWalkRelative: 'hace 1h',
    ),
    const _MockSeed(
      kind: 'Mascota · tranquila',
      size: PetSize.dogSmall,
      battery: 54,
      lastSync: 'hace 14 min',
      distanceKm: 0.6,
      activeMin: 18,
      intensityMin: 8,
      maxKmh: 6.8,
      paceMinPerKm: null,
      weekly: [0.4, 0.9, 0.3, 0.7, 0.5, 1.1, 0.6],
      lastWalkPlace: 'Casa',
      lastWalkRelative: 'hace 30 min',
    ),
    const _MockSeed(
      kind: 'Mascota · atlética',
      size: PetSize.dogLarge,
      battery: 67,
      lastSync: 'hace 5 min',
      distanceKm: 5.4,
      activeMin: 92,
      intensityMin: 58,
      maxKmh: 18.6,
      paceMinPerKm: 7.1,
      weekly: [4.2, 5.8, 6.4, 4.9, 8.3, 6.7, 5.4],
      lastWalkPlace: 'Cerros Orientales',
      lastWalkRelative: 'hace 2h',
    ),
  ];
  return seeds[index % seeds.length];
}
