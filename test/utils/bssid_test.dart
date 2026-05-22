import 'package:flutter_test/flutter_test.dart';

import 'package:pettrack_app/utils/bssid.dart';

void main() {
  group('bssidWithNeighbors', () {
    test('mid-range last byte expands to original + ±1', () {
      expect(
        bssidWithNeighbors('28:70:4e:40:18:43'),
        ['28:70:4e:40:18:43', '28:70:4e:40:18:42', '28:70:4e:40:18:44'],
      );
    });

    test('last byte = 00 wraps minus to FF (mod 256)', () {
      expect(
        bssidWithNeighbors('aa:bb:cc:dd:ee:00'),
        ['aa:bb:cc:dd:ee:00', 'aa:bb:cc:dd:ee:ff', 'aa:bb:cc:dd:ee:01'],
      );
    });

    test('last byte = FF wraps plus to 00', () {
      expect(
        bssidWithNeighbors('aa:bb:cc:dd:ee:ff'),
        ['aa:bb:cc:dd:ee:ff', 'aa:bb:cc:dd:ee:fe', 'aa:bb:cc:dd:ee:00'],
      );
    });

    test('uppercase input preserved in original; lowercase in neighbors', () {
      // We don't normalize the original (preserve what the OS gave us);
      // neighbors are emitted with lowercase hex which matches Dart's
      // toRadixString output. This is fine — the backend normalizes
      // both ends to uppercase no-separator format on insert.
      final result = bssidWithNeighbors('AA:BB:CC:DD:EE:43');
      expect(result[0], 'AA:BB:CC:DD:EE:43');
      expect(result[1], 'AA:BB:CC:DD:EE:42');
      expect(result[2], 'AA:BB:CC:DD:EE:44');
    });

    test('malformed (5 parts) returns input as-is, no expansion', () {
      expect(
        bssidWithNeighbors('aa:bb:cc:dd:ee'),
        ['aa:bb:cc:dd:ee'],
      );
    });

    test('malformed (last byte not hex) returns input as-is', () {
      expect(
        bssidWithNeighbors('aa:bb:cc:dd:ee:zz'),
        ['aa:bb:cc:dd:ee:zz'],
      );
    });

    test('malformed (single-digit byte) returns input as-is', () {
      expect(
        bssidWithNeighbors('a:bb:cc:dd:ee:43'),
        ['a:bb:cc:dd:ee:43'],
      );
    });
  });
}
