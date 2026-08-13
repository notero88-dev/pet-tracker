// Regression tests for two customer-reported defects (2026-07-31).
//
// 1. "El reloj del historial muestra una hora incorrecta (desfasada 5
//    horas)". Traccar returns ISO-8601 in UTC, so DateTime.parse yields
//    a UTC DateTime and every DateFormat rendered UTC — exactly 5 hours
//    ahead of Bogota. The collar itself was right (TZ:0; the server owns
//    the timezone), so the bug was ours.
//
// 2. "Cuando el dispositivo está en 5% ya no funciona". Correct: the
//    gateway's voltage→percent curve FLOORS at 5% for anything under
//    3.40 V, the point where the modem can no longer transmit. 5% never
//    meant "some charge left".

import 'package:flutter_test/flutter_test.dart';
import 'package:pettrack_app/models/position.dart';
import 'package:pettrack_app/utils/constants.dart';

void main() {
  group('UTC timestamps are converted to local time', () {
    test('Position.fromJson returns local DateTimes, not UTC', () {
      final pos = Position.fromJson({
        'id': 1,
        'deviceId': 8,
        'latitude': 4.679,
        'longitude': -74.052,
        'deviceTime': '2026-07-30T15:13:00.000+00:00',
        'serverTime': '2026-07-30T15:13:05.000+00:00',
      });

      expect(pos.deviceTime.isUtc, isFalse,
          reason: 'a UTC DateTime makes DateFormat render UTC');
      expect(pos.serverTime.isUtc, isFalse);

      // Same instant, just expressed locally.
      expect(pos.deviceTime.toUtc(),
          DateTime.parse('2026-07-30T15:13:00.000Z'));
    });

    test('no instant is shifted — only the representation changes', () {
      final iso = '2026-07-30T15:13:00.000Z';
      final pos = Position.fromJson({
        'id': 1,
        'deviceId': 8,
        'latitude': 0,
        'longitude': 0,
        'deviceTime': iso,
        'serverTime': iso,
      });
      expect(pos.deviceTime.millisecondsSinceEpoch,
          DateTime.parse(iso).millisecondsSinceEpoch);
    });
  });

  group('BatteryDisplay', () {
    // "Sin batería" until 2026-08-13: it reads in Spanish as "no battery
    // fitted" as easily as "the battery ran out", and the founder read it
    // the wrong way during a field test. "Agotada" only has one meaning.
    test('the 5% floor reads as "Batería agotada", not a percentage', () {
      expect(BatteryDisplay.label(5), 'Batería agotada');
      expect(BatteryDisplay.isEmpty(5), isTrue);
    });

    test('real readings still show a percentage', () {
      expect(BatteryDisplay.label(10), '10%');
      expect(BatteryDisplay.label(40), '40%');
      expect(BatteryDisplay.label(100), '100%');
      expect(BatteryDisplay.isEmpty(10), isFalse);
    });

    test('no reading shows a dash, never a made-up number', () {
      expect(BatteryDisplay.label(null), '—');
      expect(BatteryDisplay.isEmpty(null), isFalse);
    });
  });
}
