// Activity-metric calculator for the Pets + Activity Dashboard.
//
// MT710 has GPS only — no accelerometer / no heart-rate sensor — so steps
// and calories are *estimates* derived from GPS distance + active-minutes.
// All formulas are documented inline so a future engineer (or a vet) can
// challenge them. Tweak the constants here and every dashboard tile updates.
//
// Sources:
// - Step length:  veterinary observational studies place a medium dog's
//   stride at ~0.55–0.65 m on flat ground at a comfortable pace; we
//   conservatively use 0.59 m → 1.7 steps/m. Cats stride ~0.36 m →
//   2.8 steps/m. Small dogs use ~0.42 m, large dogs ~0.77 m.
// - Calorie burn:  the field standard for moderate canine walking is
//   about 0.8 kcal · kg⁻¹ · km⁻¹ on flat terrain. We add a small baseline
//   (0.05 kcal · kg⁻¹ · min⁻¹ of active time) to capture sniffing, lateral
//   movement, and short bursts the GPS distance under-counts.
// - Speed thresholds:  >1 km/h = "active" (any motion, walking inclusive),
//   >4 km/h = "intensity" (trotting/running for most pets).
//
// None of this is medically authoritative — it's a useful daily proxy.
// When a pet's profile gains weight + breed-size fields the defaults here
// can be replaced with per-pet values.

import 'dart:math' as math;

import '../models/position.dart';

/// What kind of pet the metrics are for. Drives stride length + default
/// weight when the pet's profile doesn't carry the real number yet.
enum PetSize { catSmall, dogSmall, dogMedium, dogLarge }

/// Per-PetSize defaults.
class PetSizeDefaults {
  /// Steps per meter walked on flat ground at a comfortable pace.
  static const Map<PetSize, double> stepsPerMeter = {
    PetSize.catSmall: 2.8,
    PetSize.dogSmall: 2.4,
    PetSize.dogMedium: 1.7,
    PetSize.dogLarge: 1.3,
  };

  /// Default weight in kg when the pet's profile doesn't carry one yet.
  static const Map<PetSize, double> defaultWeightKg = {
    PetSize.catSmall: 4,
    PetSize.dogSmall: 7,
    PetSize.dogMedium: 15,
    PetSize.dogLarge: 32,
  };

  /// Daily distance goal (km) we render the activity ring against.
  static const Map<PetSize, double> dailyDistanceGoalKm = {
    PetSize.catSmall: 1.5,
    PetSize.dogSmall: 3,
    PetSize.dogMedium: 5,
    PetSize.dogLarge: 7,
  };

  /// Daily active-minutes goal.
  static const Map<PetSize, int> dailyActiveMinutesGoal = {
    PetSize.catSmall: 45,
    PetSize.dogSmall: 60,
    PetSize.dogMedium: 90,
    PetSize.dogLarge: 90,
  };

  /// Daily intensity-minutes goal (trotting / running speeds).
  static const Map<PetSize, int> dailyIntensityMinutesGoal = {
    PetSize.catSmall: 20,
    PetSize.dogSmall: 30,
    PetSize.dogMedium: 60,
    PetSize.dogLarge: 60,
  };
}

/// Pure-function calculators for the dashboard tiles. No state, no IO —
/// take positions or distance, return a number.
class ActivityCalculator {
  /// Speed (km/h) above which the pet is "active" (walking included).
  static const double activeSpeedThresholdKmh = 1.0;

  /// Speed (km/h) above which the pet is "in intensity" (trot / run).
  static const double intensitySpeedThresholdKmh = 4.0;

  /// Sustained speed (km/h) above which we assume the device is in a
  /// vehicle, not the pet running. Even a Greyhound sprints around 70 km/h
  /// for at most a few seconds; sustained > 30 km/h for [vehicleSustainedSeconds]+
  /// is statistically a car/bike/transit ride. Position samples inside a
  /// run that meets both thresholds are dropped before any metric is
  /// computed — see [filterVehicleSegments].
  static const double vehicleSpeedThresholdKmh = 30.0;

  /// Minimum duration (seconds) of sustained above-threshold speed before
  /// a segment is classified as vehicle motion. One-off high-speed fixes
  /// (a sprint, GPS jitter on a cell-tower handoff) below this duration
  /// are kept; only sustained runs are dropped.
  ///
  /// Known v1 limitation: stop-and-go vehicle traffic with sub-30s bursts
  /// at 35 km/h interleaved with red-light stops at 0 km/h won't be
  /// detected by this purely speed-based filter — fixing it would require
  /// a state-machine cool-down. Acceptable for now; revisit if dashboards
  /// look inflated on real urban-driving data.
  static const int vehicleSustainedSeconds = 30;

  /// Calorie coefficient (kcal per kg per km) for moderate dog walking.
  static const double walkingKcalPerKgPerKm = 0.8;

  /// Baseline burn (kcal per kg per minute of active time) for the
  /// sniffing / lateral motion the GPS doesn't fully capture.
  static const double activeBaselineKcalPerKgPerMin = 0.05;

  /// Estimated steps from a distance.
  ///
  /// `distanceMeters` should be the sum of haversine distances between
  /// consecutive position fixes; see [distanceMetersFromPositions].
  /// Rounded to the nearest integer step.
  static int estimateSteps({
    required double distanceMeters,
    required PetSize size,
  }) {
    final perMeter = PetSizeDefaults.stepsPerMeter[size]!;
    return (distanceMeters * perMeter).round();
  }

  /// Estimated calories burned from distance + active minutes + weight.
  ///
  /// Weight is a real-world variable that would normally come from the
  /// pet's profile; pass [PetSizeDefaults.defaultWeightKg] when unknown.
  static double estimateCaloriesKcal({
    required double distanceKm,
    required int activeMinutes,
    required double weightKg,
  }) {
    final fromWalk = distanceKm * weightKg * walkingKcalPerKgPerKm;
    final fromBaseline = activeMinutes * weightKg * activeBaselineKcalPerKgPerMin;
    return fromWalk + fromBaseline;
  }

  /// Returns [positions] with vehicle-speed segments removed.
  ///
  /// A "vehicle segment" is a contiguous run of positions where every
  /// position has speed ≥ [vehicleSpeedThresholdKmh] AND the run's time
  /// span (first.deviceTime → last.deviceTime) is ≥
  /// [vehicleSustainedSeconds]. Whole runs that meet both conditions are
  /// dropped; isolated above-threshold fixes (a sprint, a GPS-jitter
  /// blip) are kept so genuine athletic bursts still count toward
  /// intensity minutes and max-speed.
  ///
  /// Idempotent: calling on an already-filtered list is a no-op (every
  /// kept run by definition fails one of the two thresholds).
  ///
  /// **Note for distance computation:** this returns a flat list, which
  /// loses the information that a vehicle gap split two walking sessions.
  /// `distanceMetersFromPositions` uses [_splitAroundVehicleSegments]
  /// instead so it can refuse to haversine across the gap.
  static List<Position> filterVehicleSegments(List<Position> positions) {
    return _splitAroundVehicleSegments(positions).expand((s) => s).toList();
  }

  /// Returns positions split into walking sequences, with each detected
  /// vehicle segment removed AND treated as a session break. Empty
  /// sequences are dropped from the result.
  ///
  /// Used by [distanceMetersFromPositions] so we don't compute haversine
  /// across a vehicle gap (e.g., car ride between two parks should not
  /// add the cross-city distance to the dog's total).
  static List<List<Position>> _splitAroundVehicleSegments(
      List<Position> positions) {
    if (positions.isEmpty) return [];
    if (positions.length == 1) return [positions];

    final segments = <List<Position>>[];
    var current = <Position>[];
    var runStart = 0;
    var runEnd = -1; // inclusive end of current above-threshold run

    void flushRun() {
      if (runEnd < runStart) return;
      final span = positions[runEnd]
          .deviceTime
          .difference(positions[runStart].deviceTime)
          .inSeconds
          .abs();
      final isVehicle =
          (runEnd > runStart) && span >= vehicleSustainedSeconds;
      if (isVehicle) {
        // Vehicle run dropped. Close the current walking segment so the
        // next position starts a fresh one — distance won't bridge the gap.
        if (current.isNotEmpty) {
          segments.add(current);
          current = <Position>[];
        }
      } else {
        // Sprint / brief blip — keep the run as part of the current segment.
        for (var i = runStart; i <= runEnd; i++) {
          current.add(positions[i]);
        }
      }
    }

    var inRun = false;
    for (var i = 0; i < positions.length; i++) {
      final overThreshold =
          (positions[i].speed ?? 0) >= vehicleSpeedThresholdKmh;
      if (overThreshold) {
        if (!inRun) {
          runStart = i;
          inRun = true;
        }
        runEnd = i;
      } else {
        if (inRun) {
          flushRun();
          inRun = false;
        }
        current.add(positions[i]);
      }
    }
    if (inRun) flushRun();
    if (current.isNotEmpty) segments.add(current);
    return segments;
  }

  /// Implied-speed threshold (km/h) above which a haversine segment is
  /// rejected as a teleport / re-ordered late fix. 60 km/h is well above
  /// any pet's running speed but still permissive enough that a real
  /// post-vehicle-filter walk segment (~5 km/h) is never wrongly
  /// dropped — the hard ceiling is a sanity check, not a primary filter.
  static const double teleportImpliedSpeedKmh = 60.0;

  /// Sum of haversine distances between consecutive [positions], in meters.
  ///
  /// Splits vehicle segments out via [_splitAroundVehicleSegments] so a
  /// car ride between two parks is treated as two separate walking
  /// sequences (not one continuous walk that "happens to teleport across
  /// town"). Per-segment, rejects pairs whose haversine over time gap
  /// implies speed > [teleportImpliedSpeedKmh] — catches stale-fix
  /// reorders without hurting normal slow walks. Empty / single-position
  /// lists return 0.
  static double distanceMetersFromPositions(List<Position> positions) {
    final segments = _splitAroundVehicleSegments(positions);
    double total = 0;
    for (final segment in segments) {
      if (segment.length < 2) continue;
      for (var i = 1; i < segment.length; i++) {
        final a = segment[i - 1];
        final b = segment[i];
        final dist = _haversineMeters(
          a.latitude, a.longitude, b.latitude, b.longitude,
        );
        final dtSec = b.deviceTime.difference(a.deviceTime).inSeconds.abs();
        // Implied km/h = (segment_m / dt_s) × 3.6. dtSec == 0 means
        // simultaneous fixes → infinite implied speed → drop.
        final impliedKmh =
            dtSec > 0 ? (dist / dtSec) * 3.6 : double.infinity;
        if (impliedKmh > teleportImpliedSpeedKmh) continue;
        total += dist;
      }
    }
    return total;
  }

  /// Active minutes — count of position samples whose reported speed is
  /// above [activeSpeedThresholdKmh]. Each sample roughly stands in for
  /// one minute of motion; this is approximate, not a stopwatch.
  ///
  /// Vehicle segments are dropped first via [filterVehicleSegments] so a
  /// 20-minute car ride doesn't show up as 20 minutes of "activity".
  /// Position speed is already in km/h per the Traccar model.
  static int activeMinutesFromPositions(List<Position> positions) {
    return filterVehicleSegments(positions)
        .where((p) => (p.speed ?? 0) >= activeSpeedThresholdKmh)
        .length;
  }

  /// Intensity minutes — same logic as active, but at the higher
  /// [intensitySpeedThresholdKmh] threshold.
  static int intensityMinutesFromPositions(List<Position> positions) {
    return filterVehicleSegments(positions)
        .where((p) => (p.speed ?? 0) >= intensitySpeedThresholdKmh)
        .length;
  }

  /// Average pace in minutes per km. Returns null when distance is zero.
  ///
  /// Formatted for display as `M'SS"` by [formatPace].
  static double? averagePaceMinPerKm({
    required double distanceKm,
    required int activeMinutes,
  }) {
    if (distanceKm <= 0) return null;
    return activeMinutes / distanceKm;
  }

  /// Format a pace value (decimal minutes/km) as `7'58"` for display.
  static String formatPace(double? minPerKm) {
    if (minPerKm == null || !minPerKm.isFinite) return '—';
    final minutes = minPerKm.floor();
    final seconds = ((minPerKm - minutes) * 60).round();
    return "$minutes'${seconds.toString().padLeft(2, '0')}\"";
  }

  /// Maximum speed reached (km/h) across the supplied positions, after
  /// vehicle segments are filtered out via [filterVehicleSegments].
  /// A 50 km/h car ride won't show up as the pet's max speed; an
  /// in-the-clear 28 km/h sprint will.
  static double maxSpeedKmh(List<Position> positions) {
    final filtered = filterVehicleSegments(positions);
    if (filtered.isEmpty) return 0;
    return filtered.map((p) => p.speed ?? 0.0).reduce(math.max);
  }

  // -- Haversine ------------------------------------------------------------

  static double _haversineMeters(
    double lat1, double lon1, double lat2, double lon2,
  ) {
    const earthRadiusMeters = 6371000.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) *
            math.cos(_deg2rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  static double _deg2rad(double deg) => deg * math.pi / 180;
}
