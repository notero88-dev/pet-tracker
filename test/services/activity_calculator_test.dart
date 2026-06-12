// Pure-function tests for ActivityCalculator. Hits each numeric formula's
// edge cases and the two filters (teleport + vehicle-segment) so future
// tweaks don't silently regress dashboard accuracy.
//
// Run: `flutter test test/services/activity_calculator_test.dart`

import 'package:flutter_test/flutter_test.dart';
import 'package:pettrack_app/models/position.dart';
import 'package:pettrack_app/services/activity_calculator.dart';

/// Quick Position factory — every test builds positions, this trims the
/// boilerplate. `t0`-relative times in seconds, default speed 0 km/h,
/// default coords on Bogotá's Plaza de Bolívar.
Position _pos({
  required int idx,
  required int secondsFromT0,
  double lat = 4.5981,
  double lon = -74.0758,
  double? speedKmh,
}) {
  final t0 = DateTime.utc(2026, 5, 7, 12, 0, 0);
  final t = t0.add(Duration(seconds: secondsFromT0));
  return Position(
    id: idx,
    deviceId: 1,
    deviceTime: t,
    serverTime: t,
    latitude: lat,
    longitude: lon,
    speed: speedKmh,
  );
}

void main() {
  group('empty / single-position lists', () {
    test('distance returns 0 for empty list', () {
      expect(ActivityCalculator.distanceMetersFromPositions([]), 0);
    });
    test('distance returns 0 for one position', () {
      expect(
        ActivityCalculator.distanceMetersFromPositions([_pos(idx: 1, secondsFromT0: 0)]),
        0,
      );
    });
    test('active + intensity + maxSpeed return 0 for empty list', () {
      expect(ActivityCalculator.activeMinutesFromPositions([]), 0);
      expect(ActivityCalculator.intensityMinutesFromPositions([]), 0);
      expect(ActivityCalculator.maxSpeedKmh([]), 0);
    });
    test('estimateSteps with 0 distance returns 0', () {
      expect(
        ActivityCalculator.estimateSteps(distanceMeters: 0, size: PetSize.dogMedium),
        0,
      );
    });
    test('estimateCalories with 0 distance + 0 active returns 0', () {
      expect(
        ActivityCalculator.estimateCaloriesKcal(
          distanceKm: 0,
          activeMinutes: 0,
          weightKg: 15,
        ),
        0,
      );
    });
  });

  group('distance calculation', () {
    test('two positions ~1 km apart accumulate ~1 km', () {
      // ~0.009° latitude ≈ 1 km
      final positions = [
        _pos(idx: 1, secondsFromT0: 0, lat: 4.6000, lon: -74.0758, speedKmh: 5),
        _pos(idx: 2, secondsFromT0: 1800, lat: 4.6090, lon: -74.0758, speedKmh: 5),
      ];
      final meters = ActivityCalculator.distanceMetersFromPositions(positions);
      expect(meters, closeTo(1000, 50));
    });

    test('teleport — 30 km jump in 10 min is rejected', () {
      final positions = [
        _pos(idx: 1, secondsFromT0: 0, lat: 4.6000, lon: -74.0758, speedKmh: 5),
        _pos(idx: 2, secondsFromT0: 600, lat: 4.8700, lon: -74.0758, speedKmh: 5),
      ];
      // The huge segment is dropped → total distance = 0.
      expect(
        ActivityCalculator.distanceMetersFromPositions(positions),
        0,
      );
    });
  });

  group('vehicle-segment filter', () {
    test('sustained 50 km/h car ride is dropped from distance + max speed', () {
      // 10 fixes, 30s apart, all at 50 km/h, advancing east by ~0.0045°
      // each (≈ 500 m every 30s ≈ 60 km/h ground speed). Span = 270s,
      // well over the 30s sustained threshold.
      final carRide = <Position>[
        for (var i = 0; i < 10; i++)
          _pos(
            idx: 100 + i,
            secondsFromT0: 1000 + i * 30,
            lat: 4.6000,
            lon: -74.0758 + i * 0.0045,
            speedKmh: 50,
          ),
      ];
      // Plus a short walk before + after, separated by enough time that
      // teleport-rejection won't cross-fire.
      final beforeWalk = [
        _pos(idx: 1, secondsFromT0: 0, lat: 4.6000, lon: -74.0758, speedKmh: 4),
        _pos(idx: 2, secondsFromT0: 240, lat: 4.6005, lon: -74.0758, speedKmh: 4),
      ];
      final afterWalk = [
        _pos(idx: 200, secondsFromT0: 1500, lat: 4.6045, lon: -74.0300, speedKmh: 3),
        _pos(idx: 201, secondsFromT0: 1740, lat: 4.6050, lon: -74.0300, speedKmh: 3),
      ];
      final all = [...beforeWalk, ...carRide, ...afterWalk];

      // Filter directly: only the 4 walk positions remain.
      final filtered = ActivityCalculator.filterVehicleSegments(all);
      expect(filtered.length, 4);

      // Max speed ignores the car ride.
      expect(ActivityCalculator.maxSpeedKmh(all), 4);

      // Distance reflects only the walks (~50 m each, total ≈ 100 m).
      // Note: distance from afterWalk's first position would haversine
      // back to beforeWalk's last position, but the teleport-reject gate
      // catches it (the gap is > 1 km AND > 5 min).
      final distM = ActivityCalculator.distanceMetersFromPositions(all);
      expect(distM, lessThan(200));
    });

    test('25-second sprint at 35 km/h is KEPT (sub-sustained-threshold)', () {
      // 2 fixes, 25 seconds apart, both above the 30 km/h threshold but
      // span < 30s sustained. Should be kept as a sprint — counts toward
      // intensity minutes + max speed.
      final positions = [
        _pos(idx: 1, secondsFromT0: 0, lat: 4.6000, lon: -74.0758, speedKmh: 4),
        _pos(idx: 2, secondsFromT0: 60, lat: 4.6004, lon: -74.0758, speedKmh: 35),
        _pos(idx: 3, secondsFromT0: 85, lat: 4.6008, lon: -74.0758, speedKmh: 35),
        _pos(idx: 4, secondsFromT0: 120, lat: 4.6012, lon: -74.0758, speedKmh: 4),
      ];
      final filtered = ActivityCalculator.filterVehicleSegments(positions);
      expect(filtered.length, 4); // sprint kept
      expect(ActivityCalculator.maxSpeedKmh(positions), 35);
    });
  });

  group('active + intensity minutes', () {
    test('5 fixes — 3 walking, 1 trotting, 1 still', () {
      final positions = [
        _pos(idx: 1, secondsFromT0: 0, speedKmh: 0),     // still
        _pos(idx: 2, secondsFromT0: 60, speedKmh: 2),    // walk
        _pos(idx: 3, secondsFromT0: 120, speedKmh: 3),   // walk
        _pos(idx: 4, secondsFromT0: 180, speedKmh: 5),   // trot (active + intensity)
        _pos(idx: 5, secondsFromT0: 240, speedKmh: 1.5), // walk
      ];
      expect(ActivityCalculator.activeMinutesFromPositions(positions), 4);
      expect(ActivityCalculator.intensityMinutesFromPositions(positions), 1);
    });
  });

  group('estimateSteps', () {
    test('1 km for medium dog ≈ 1700 steps', () {
      final steps = ActivityCalculator.estimateSteps(
        distanceMeters: 1000,
        size: PetSize.dogMedium,
      );
      expect(steps, 1700);
    });
    test('size scales correctly: small > medium > large; cat highest', () {
      final small = ActivityCalculator.estimateSteps(
        distanceMeters: 1000, size: PetSize.dogSmall);
      final medium = ActivityCalculator.estimateSteps(
        distanceMeters: 1000, size: PetSize.dogMedium);
      final large = ActivityCalculator.estimateSteps(
        distanceMeters: 1000, size: PetSize.dogLarge);
      final cat = ActivityCalculator.estimateSteps(
        distanceMeters: 1000, size: PetSize.catSmall);
      expect(small, greaterThan(medium));
      expect(medium, greaterThan(large));
      expect(cat, greaterThan(small));
    });
  });

  group('estimateCalories', () {
    test('5 km + 60 min active for 15 kg dog ≈ 105 kcal', () {
      // 5 × 15 × 0.8 = 60 (walking)
      // 60 × 15 × 0.05 = 45 (baseline)
      // total = 105
      final cal = ActivityCalculator.estimateCaloriesKcal(
        distanceKm: 5,
        activeMinutes: 60,
        weightKg: 15,
      );
      expect(cal, closeTo(105, 0.001));
    });
  });

  group('formatPace', () {
    test('null pace formats as em dash', () {
      expect(ActivityCalculator.formatPace(null), '—');
    });
    test('8.2 min/km formats as 8\'12"', () {
      // .2 of a minute = 12s
      expect(ActivityCalculator.formatPace(8.2), '8\'12"');
    });
    test('infinity formats as em dash', () {
      expect(ActivityCalculator.formatPace(double.infinity), '—');
    });
  });

  group('averagePaceMinPerKm', () {
    test('null when distance is 0', () {
      expect(
        ActivityCalculator.averagePaceMinPerKm(distanceKm: 0, activeMinutes: 30),
        null,
      );
    });
    test('30 min over 5 km → 6.0 min/km', () {
      expect(
        ActivityCalculator.averagePaceMinPerKm(distanceKm: 5, activeMinutes: 30),
        6.0,
      );
    });
  });
}
