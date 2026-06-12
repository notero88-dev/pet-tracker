// Shared palette used by both the mock + real activity builders to pick
// a stable avatar gradient per pet. Hash-based so the same pet always
// gets the same color, regardless of which builder produced its
// DailyActivity.

import 'package:flutter/material.dart';

const List<List<Color>> petAvatarPalette = [
  [Color(0xFFF4D9A8), Color(0xFFE8A33D)], // marigold
  [Color(0xFFD9DEE6), Color(0xFF5F6876)], // slate
  [Color(0xFFF2DCD4), Color(0xFFC97A6E)], // dusk
  [Color(0xFFC9E5DA), Color(0xFF2F6B5C)], // sabana
  [Color(0xFFE6D7C5), Color(0xFF6B4A34)], // cafe
];

/// Pick a deterministic gradient (top, bottom) for a pet name. Same name
/// in → same gradient out, every time.
List<Color> petAvatarFor(String name) {
  if (name.isEmpty) return petAvatarPalette[0];
  final hash =
      name.codeUnits.fold<int>(0, (a, c) => (a + c) % petAvatarPalette.length);
  return petAvatarPalette[hash];
}
