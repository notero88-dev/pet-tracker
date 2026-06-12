// One day's worth of activity metrics for a single pet, ready to render
// onto the activity-dashboard widgets. Combines pet identity + computed
// metrics + weekly trend so the screen has everything it needs in one
// object — no further async work after this is built.
//
// Computation lives in `services/activity_calculator.dart`. This file is
// only the data shape + the two factories: `compute()` from real Traccar
// positions, and `mock()` for design-time / hardcoded demo pets.

import 'dart:ui';

import '../services/activity_calculator.dart';
import 'position.dart';

/// Status kind shown next to the pet name. Keep narrow — extend when a
/// new state warrants its own visual treatment.
enum PetActivityStatus { safe, home, offline }

class DailyActivity {
  // -- Pet identity --------------------------------------------------------
  final String petId;
  final String name;
  final String kind;
  final PetSize size;
  final double weightKg;
  final Color avatarTop;
  final Color avatarBottom;

  // -- Live status ---------------------------------------------------------
  final bool online;
  final int batteryPercent;
  final String lastSyncRelative; // "hace 2 min"
  final PetActivityStatus status;

  // -- Today's totals ------------------------------------------------------
  final double distanceKm;
  final int activeMinutes;
  final int intensityMinutes;
  final int steps;
  final int caloriesKcal;

  // -- Goals ---------------------------------------------------------------
  final double distanceGoalKm;
  final int activeGoalMinutes;
  final int intensityGoalMinutes;

  // -- Speed / pace --------------------------------------------------------
  final double? averagePaceMinPerKm; // null when distance is 0
  final double maxSpeedKmh;

  // -- Weekly trend (last 7 days, oldest first) ---------------------------
  /// Distance (km) per day, oldest → newest. Length must be 7.
  final List<double> weeklyDistanceKm;
  /// Day-letter labels matching [weeklyDistanceKm] (e.g. ['L','M','M','J','V','S','D']).
  final List<String> weeklyDayLabels;

  // -- Recent context (display-only) --------------------------------------
  final String lastWalkPlace;
  final String lastWalkRelative;

  const DailyActivity({
    required this.petId,
    required this.name,
    required this.kind,
    required this.size,
    required this.weightKg,
    required this.avatarTop,
    required this.avatarBottom,
    required this.online,
    required this.batteryPercent,
    required this.lastSyncRelative,
    required this.status,
    required this.distanceKm,
    required this.activeMinutes,
    required this.intensityMinutes,
    required this.steps,
    required this.caloriesKcal,
    required this.distanceGoalKm,
    required this.activeGoalMinutes,
    required this.intensityGoalMinutes,
    required this.averagePaceMinPerKm,
    required this.maxSpeedKmh,
    required this.weeklyDistanceKm,
    required this.weeklyDayLabels,
    required this.lastWalkPlace,
    required this.lastWalkRelative,
  });

  /// Build a [DailyActivity] from a real list of today's positions for
  /// one pet, plus its profile and the prior 6 days' distance totals.
  ///
  /// [todayPositions] is the chronologically ordered sequence of fixes
  /// from 00:00 local time → now. [priorDaysDistanceKm] is six numbers
  /// for the six days before today (oldest first). The weekly chart
  /// concatenates them with today's computed distance.
  factory DailyActivity.compute({
    required String petId,
    required String name,
    required String kind,
    required PetSize size,
    required double? weightKg,
    required Color avatarTop,
    required Color avatarBottom,
    required bool online,
    required int batteryPercent,
    required String lastSyncRelative,
    required PetActivityStatus status,
    required List<Position> todayPositions,
    required List<double> priorDaysDistanceKm,
    required List<String> weeklyDayLabels,
    String lastWalkPlace = '',
    String lastWalkRelative = '',
  }) {
    final weight = weightKg ?? PetSizeDefaults.defaultWeightKg[size]!;
    final distanceMeters =
        ActivityCalculator.distanceMetersFromPositions(todayPositions);
    final distanceKm = distanceMeters / 1000;
    final activeMin =
        ActivityCalculator.activeMinutesFromPositions(todayPositions);
    final intensityMin =
        ActivityCalculator.intensityMinutesFromPositions(todayPositions);
    final steps = ActivityCalculator.estimateSteps(
      distanceMeters: distanceMeters,
      size: size,
    );
    final calories = ActivityCalculator.estimateCaloriesKcal(
      distanceKm: distanceKm,
      activeMinutes: activeMin,
      weightKg: weight,
    );
    final pace = ActivityCalculator.averagePaceMinPerKm(
      distanceKm: distanceKm,
      activeMinutes: activeMin,
    );
    final maxKmh = ActivityCalculator.maxSpeedKmh(todayPositions);

    final weekly = <double>[...priorDaysDistanceKm, distanceKm];
    assert(weekly.length == 7,
        'priorDaysDistanceKm must have exactly 6 entries (got ${priorDaysDistanceKm.length}); weekly chart needs 7 days total');
    assert(weeklyDayLabels.length == 7,
        'weeklyDayLabels must have exactly 7 entries');

    return DailyActivity(
      petId: petId,
      name: name,
      kind: kind,
      size: size,
      weightKg: weight,
      avatarTop: avatarTop,
      avatarBottom: avatarBottom,
      online: online,
      batteryPercent: batteryPercent,
      lastSyncRelative: lastSyncRelative,
      status: status,
      distanceKm: distanceKm,
      activeMinutes: activeMin,
      intensityMinutes: intensityMin,
      steps: steps,
      caloriesKcal: calories.round(),
      distanceGoalKm: PetSizeDefaults.dailyDistanceGoalKm[size]!,
      activeGoalMinutes: PetSizeDefaults.dailyActiveMinutesGoal[size]!,
      intensityGoalMinutes: PetSizeDefaults.dailyIntensityMinutesGoal[size]!,
      averagePaceMinPerKm: pace,
      maxSpeedKmh: maxKmh,
      weeklyDistanceKm: weekly,
      weeklyDayLabels: weeklyDayLabels,
      lastWalkPlace: lastWalkPlace,
      lastWalkRelative: lastWalkRelative,
    );
  }

  /// Quick factory for design-time / demo pets when there's no real
  /// position history yet. The dashboard layout is identical — the
  /// numbers are just hardcoded.
  factory DailyActivity.mock({
    required String petId,
    required String name,
    required String kind,
    required PetSize size,
    required Color avatarTop,
    required Color avatarBottom,
    required bool online,
    required int batteryPercent,
    required String lastSyncRelative,
    required PetActivityStatus status,
    required double distanceKm,
    required int activeMinutes,
    required int intensityMinutes,
    required double maxSpeedKmh,
    required double? averagePaceMinPerKm,
    required List<double> weeklyDistanceKm,
    required List<String> weeklyDayLabels,
    String lastWalkPlace = '',
    String lastWalkRelative = '',
    double? weightKg,
  }) {
    final weight = weightKg ?? PetSizeDefaults.defaultWeightKg[size]!;
    final steps = ActivityCalculator.estimateSteps(
      distanceMeters: distanceKm * 1000,
      size: size,
    );
    final calories = ActivityCalculator.estimateCaloriesKcal(
      distanceKm: distanceKm,
      activeMinutes: activeMinutes,
      weightKg: weight,
    );
    return DailyActivity(
      petId: petId,
      name: name,
      kind: kind,
      size: size,
      weightKg: weight,
      avatarTop: avatarTop,
      avatarBottom: avatarBottom,
      online: online,
      batteryPercent: batteryPercent,
      lastSyncRelative: lastSyncRelative,
      status: status,
      distanceKm: distanceKm,
      activeMinutes: activeMinutes,
      intensityMinutes: intensityMinutes,
      steps: steps,
      caloriesKcal: calories.round(),
      distanceGoalKm: PetSizeDefaults.dailyDistanceGoalKm[size]!,
      activeGoalMinutes: PetSizeDefaults.dailyActiveMinutesGoal[size]!,
      intensityGoalMinutes: PetSizeDefaults.dailyIntensityMinutesGoal[size]!,
      averagePaceMinPerKm: averagePaceMinPerKm,
      maxSpeedKmh: maxSpeedKmh,
      weeklyDistanceKm: weeklyDistanceKm,
      weeklyDayLabels: weeklyDayLabels,
      lastWalkPlace: lastWalkPlace,
      lastWalkRelative: lastWalkRelative,
    );
  }
}
