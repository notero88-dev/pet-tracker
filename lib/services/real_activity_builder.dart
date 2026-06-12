// Builds the dashboard's [DailyActivity] list from real Firestore pets +
// real Traccar position history. Replacement for `mock_activity_data.dart`'s
// `mockActivitiesForDevices()` once a user has at least one provisioned
// pet.
//
// Strategy:
//   1. Read pet docs from Firestore (`getUserPets()`).
//   2. For every pet that has a `traccarDeviceId`, fire one Traccar
//      `loadPositionHistory` request for the last 7 days (D-6 → now).
//      All pet requests run concurrently via `Future.wait`.
//   3. Partition each pet's positions by local calendar day.
//   4. Run today's positions through `DailyActivity.compute(...)` (which
//      already invokes `ActivityCalculator` — including the vehicle-segment
//      filter we just added).
//   5. Compute prior-day distances via `ActivityCalculator.distanceMetersFromPositions`.
//
// Failure mode: a per-pet Traccar exception falls back to a `mock()`
// entry for that pet, so a single broken IMEI doesn't take the dashboard
// down for the whole household.
//
// V2 will replace the per-day distance loop with a backend rollup query;
// see KANBAN "Phase 3 — backend rollup" follow-up.

import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';

import '../models/daily_activity.dart';
import '../models/position.dart';
import '../providers/traccar_provider.dart';
import '../screens/activity/pet_avatar_palette.dart';
import 'activity_calculator.dart';
import 'firestore_service.dart';
import 'pet_size_inference.dart';

const List<String> _weekdayLabels = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

/// Build [DailyActivity] entries for every pet the current Firestore user
/// owns, computing today's metrics from live Traccar positions and the
/// six prior days from the same one-shot 7-day fetch.
Future<List<DailyActivity>> realActivitiesForUser({
  required TraccarProvider traccar,
  required FirestoreService firestore,
}) async {
  final pets = await firestore.getUserPets();
  debugPrint(
    '[real_activity_builder] firestore returned ${pets.length} pet(s)',
  );
  for (final p in pets) {
    debugPrint(
      '[real_activity_builder]   - ${p['name']} '
      '(id=${p['id']}, '
      'traccarDeviceId=${p['traccarDeviceId']} '
      '<${p['traccarDeviceId'].runtimeType}>)',
    );
  }
  if (pets.isEmpty) return [];

  // Build the 7-day window once so all pets agree on what "today" is.
  final now = DateTime.now();
  final today00 = DateTime(now.year, now.month, now.day);
  final windowStart = today00.subtract(const Duration(days: 6));
  // Day-letter labels aligned to the window (oldest → today). Dart
  // weekday is 1=Mon … 7=Sun; we need ['L','M','M','J','V','S','D'].
  final labels = <String>[
    for (var i = 0; i < 7; i++)
      _weekdayLabels[(windowStart.add(Duration(days: i)).weekday - 1) % 7],
  ];

  final futures = pets.map((pet) => _buildOne(
        pet: pet,
        traccar: traccar,
        windowStart: windowStart,
        windowEnd: now,
        today00: today00,
        labels: labels,
      ));
  return Future.wait(futures);
}

Future<DailyActivity> _buildOne({
  required Map<String, dynamic> pet,
  required TraccarProvider traccar,
  required DateTime windowStart,
  required DateTime windowEnd,
  required DateTime today00,
  required List<String> labels,
}) async {
  final name = (pet['name'] as String?) ?? 'Mascota';
  final petId = (pet['id'] as String?) ?? name;
  final type = pet['type'] as String?;
  final breed = pet['breed'] as String?;
  final weightKg =
      (pet['weight'] is num) ? (pet['weight'] as num).toDouble() : null;
  final size = PetSizeInference.infer(
    type: type,
    breed: breed,
    weightKg: weightKg,
  );
  final colors = petAvatarFor(name);
  final kind = _formatKind(type: type, breed: breed);

  final traccarDeviceId = pet['traccarDeviceId'];
  if (traccarDeviceId is! int) {
    debugPrint(
      '[real_activity_builder] $name → FALLBACK: traccarDeviceId is '
      'not an int (value=$traccarDeviceId, '
      'type=${traccarDeviceId.runtimeType}). Did pet provisioning fail '
      'to write traccarDeviceId on the Firestore doc?',
    );
    // No device wired up — skip Traccar, return an offline entry.
    return _offlineFallback(
      petId: petId,
      name: name,
      kind: kind,
      size: size,
      weightKg: weightKg,
      avatarTop: colors[0],
      avatarBottom: colors[1],
      labels: labels,
      lastSyncRelative: 'sin dispositivo',
    );
  }

  try {
    final positions = await traccar.loadPositionHistory(
      deviceId: traccarDeviceId,
      from: windowStart,
      to: windowEnd,
    );
    debugPrint(
      '[real_activity_builder] $name (traccarDeviceId=$traccarDeviceId): '
      'loadPositionHistory returned ${positions.length} positions',
    );
    return _composeActivity(
      petId: petId,
      name: name,
      kind: kind,
      size: size,
      weightKg: weightKg,
      avatarTop: colors[0],
      avatarBottom: colors[1],
      windowStart: windowStart,
      today00: today00,
      labels: labels,
      positions: positions,
    );
  } catch (e, st) {
    debugPrint('[real_activity_builder] $name failed: $e\n$st');
    return _offlineFallback(
      petId: petId,
      name: name,
      kind: kind,
      size: size,
      weightKg: weightKg,
      avatarTop: colors[0],
      avatarBottom: colors[1],
      labels: labels,
      lastSyncRelative: 'sin conexión',
    );
  }
}

DailyActivity _composeActivity({
  required String petId,
  required String name,
  required String kind,
  required PetSize size,
  required double? weightKg,
  required Color avatarTop,
  required Color avatarBottom,
  required DateTime windowStart,
  required DateTime today00,
  required List<String> labels,
  required List<Position> positions,
}) {
  // Partition positions into 7 day-buckets by local calendar day.
  final buckets = List<List<Position>>.generate(7, (_) => <Position>[]);
  for (final p in positions) {
    final t = p.deviceTime.toLocal();
    final dayMidnight = DateTime(t.year, t.month, t.day);
    final idx = dayMidnight.difference(windowStart).inDays;
    if (idx < 0 || idx > 6) continue; // outside the 7-day window — skip
    buckets[idx].add(p);
  }
  // Sort each bucket chronologically — Traccar usually returns ascending,
  // but a safety sort costs O(n log n) and protects the haversine sum
  // from re-ordered fixes.
  for (final b in buckets) {
    b.sort((a, b) => a.deviceTime.compareTo(b.deviceTime));
  }

  final todayPositions = buckets[6];
  final priorDays = <double>[
    for (var i = 0; i < 6; i++)
      ActivityCalculator.distanceMetersFromPositions(buckets[i]) / 1000,
  ];

  // Status fields come from the most-recent position across the window.
  final lastPos = positions.isNotEmpty ? positions.last : null;
  final battery = lastPos?.batteryLevel ?? 0;
  final isOnline = lastPos != null && lastPos.isRecent;
  final lastSync = _relativeLastSync(lastPos?.deviceTime);

  return DailyActivity.compute(
    petId: petId,
    name: name,
    kind: kind,
    size: size,
    weightKg: weightKg,
    avatarTop: avatarTop,
    avatarBottom: avatarBottom,
    online: isOnline,
    batteryPercent: battery,
    lastSyncRelative: lastSync,
    status: isOnline
        ? PetActivityStatus.safe
        : PetActivityStatus.offline,
    todayPositions: todayPositions,
    priorDaysDistanceKm: priorDays,
    weeklyDayLabels: labels,
  );
}

DailyActivity _offlineFallback({
  required String petId,
  required String name,
  required String kind,
  required PetSize size,
  required double? weightKg,
  required Color avatarTop,
  required Color avatarBottom,
  required List<String> labels,
  required String lastSyncRelative,
}) {
  return DailyActivity.mock(
    petId: petId,
    name: name,
    kind: kind,
    size: size,
    weightKg: weightKg,
    avatarTop: avatarTop,
    avatarBottom: avatarBottom,
    online: false,
    batteryPercent: 0,
    lastSyncRelative: lastSyncRelative,
    status: PetActivityStatus.offline,
    distanceKm: 0,
    activeMinutes: 0,
    intensityMinutes: 0,
    maxSpeedKmh: 0,
    averagePaceMinPerKm: null,
    weeklyDistanceKm: const [0, 0, 0, 0, 0, 0, 0],
    weeklyDayLabels: labels,
  );
}

String _formatKind({String? type, String? breed}) {
  final t = (type ?? '').toLowerCase().trim();
  final b = (breed ?? '').trim();
  final typeEs = t == 'cat' || t == 'gato' || t == 'felino' ? 'Gato' : 'Perro';
  if (b.isEmpty) return typeEs;
  return '$typeEs · $b';
}

String _relativeLastSync(DateTime? when) {
  if (when == null) return 'sin datos';
  final delta = DateTime.now().difference(when);
  if (delta.inSeconds < 60) return 'hace unos segundos';
  if (delta.inMinutes < 60) return 'hace ${delta.inMinutes} min';
  if (delta.inHours < 24) return 'hace ${delta.inHours} h';
  if (delta.inDays < 7) return 'hace ${delta.inDays} d';
  return 'hace más de una semana';
}
