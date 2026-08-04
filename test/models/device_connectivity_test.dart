// Regression tests for DeviceConnectivity (2026-08-02).
//
// A MODE 8 collar sleeps by design when the pet is home — hours of
// silence are its healthy state. The old binary online/disconnected
// painted every sleeping collar red on day one ("pensé que no estaba
// funcionando" — customer onboarding report). These tests pin the
// three buckets and their boundaries.

import 'package:flutter_test/flutter_test.dart';
import 'package:pettrack_app/models/device.dart';

Device _deviceSeen(Duration ago) => Device(
      id: 1,
      name: 'Kora',
      uniqueId: '866392069996373',
      traccarId: 44,
      status: 'active',
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
      lastUpdate: DateTime.now().subtract(ago),
    );

void main() {
  group('DeviceConnectivity buckets', () {
    test('reported minutes ago → online', () {
      final d = _deviceSeen(const Duration(minutes: 5));
      expect(d.connectivity, DeviceConnectivity.online);
      expect(d.statusText, 'En línea');
    });

    test('quiet for hours → resting, NOT disconnected', () {
      final d = _deviceSeen(const Duration(hours: 3));
      expect(d.connectivity, DeviceConnectivity.resting);
      expect(d.statusText, 'En reposo');
    });

    test('silent for over a day → offline', () {
      final d = _deviceSeen(const Duration(hours: 25));
      expect(d.connectivity, DeviceConnectivity.offline);
      expect(d.statusText, 'Desconectado');
    });

    test('never seen → offline', () {
      final d = Device(
        id: 1,
        name: 'x',
        uniqueId: '0',
        traccarId: 1,
        status: 'active',
        createdAt: DateTime.now(),
        lastUpdate: null,
      );
      expect(d.connectivity, DeviceConnectivity.offline);
    });

    test('a UTC lastUpdate is bucketed by true elapsed time', () {
      // difference() compares instants, so a UTC timestamp must not
      // shift the bucket by the 5-hour Bogota offset.
      final d = Device(
        id: 1,
        name: 'x',
        uniqueId: '0',
        traccarId: 1,
        status: 'active',
        createdAt: DateTime.now(),
        lastUpdate:
            DateTime.now().toUtc().subtract(const Duration(minutes: 10)),
      );
      expect(d.connectivity, DeviceConnectivity.online);
    });
  });
}
