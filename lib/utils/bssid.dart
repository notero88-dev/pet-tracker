// BSSID utilities — small + pure functions, no Flutter dependency.
//
// Used by the home-zone setup flow to widen the device's home-WiFi MAC
// list with neighbor BSSIDs (last-byte ±1). Background:
//
//   Enterprise APs (and many home dual-band routers) broadcast multiple
//   BSSIDs per physical AP — one for the 2.4 GHz radio, one for 5 GHz,
//   sometimes one per SSID (Corporate / Guest). These BSSIDs are
//   sequential, differing by 1 in the last byte. iOS's
//   CNCopyCurrentNetworkInfo returns whichever radio the PHONE
//   connected to (most modern phones default to 5 GHz). But the MT710's
//   WiFi chip scans 2.4 GHz preferentially — so when the device tries
//   to match the configured BSSID against what it sees, it MISSES
//   because the BSSID we captured belongs to the 5 GHz radio of the
//   same physical AP.
//
//   The 2026-05-21 Habi incident: home-setup captured
//   28:70:4e:40:18:43 (5 GHz). The MT710 in scans only ever saw
//   28:70:4e:40:18:42 (2.4 GHz of the same AP). Mode 8 never matched,
//   never entered home-sleep, device ran in outdoor mode 24/7,
//   battery drained ~2x faster than expected. Fix: configure ALL THREE
//   variants (original + last-byte-minus-1 + last-byte-plus-1) so
//   whichever radio the MT710 actually sees, it'll match.
//
//   Full writeup in
//   pettrack-backend/docs/runbooks/debugging-device-silence.md and
//   pettrack-backend/docs/KANBAN.md row "Two-state mode-switching".

/// Returns the input BSSID + the two neighbor BSSIDs (last byte ±1).
///
/// Output order is **[original, originalMinus1, originalPlus1]** —
/// matches the on-wire AP command's slot order (`AP,,,MAC1,MAC2,MAC3`).
/// The backend stores all three in `device_desired_state.target_macs`
/// and forwards them verbatim to the device.
///
/// Last-byte arithmetic uses mod 256 (wrap-around). If the wrap
/// produces a MAC that doesn't physically exist on the network, the
/// device just never matches it — harmless. The "real" neighbor is
/// always one of the three.
///
/// Returns `[bssid]` (no expansion) if the input is malformed — the
/// caller should still send the original even if we can't compute
/// neighbors.
///
/// Format expected: `XX:XX:XX:XX:XX:XX` (six 2-hex-digit pairs,
/// colon-separated, case-insensitive). Matches what
/// `NetworkInfo.getWifiBSSID()` returns on iOS via
/// `network_info_plus`.
List<String> bssidWithNeighbors(String bssid) {
  final parts = bssid.split(':');
  if (parts.length != 6) return [bssid];
  if (parts.any((p) => p.length != 2)) return [bssid];

  final lastByte = int.tryParse(parts[5], radix: 16);
  if (lastByte == null) return [bssid];

  final prefix = parts.sublist(0, 5).join(':');
  String mac(int byte) =>
      '$prefix:${byte.toRadixString(16).padLeft(2, '0')}';

  // Mod-256 wrap is intentional — see top-of-file comment.
  final minus = (lastByte - 1) & 0xFF;
  final plus = (lastByte + 1) & 0xFF;

  return [bssid, mac(minus), mac(plus)];
}
