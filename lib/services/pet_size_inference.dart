// Best-effort inference of [PetSize] from the fields a pet's Firestore
// record carries today (`type`, `breed`, `weight` — see firestore_service.
// dart). Used by `real_activity_builder.dart` to feed the calculator the
// right step-length / weight / goal defaults until we capture an explicit
// `size` field on the pet model (Phase 2 of the activity-metrics plan).
//
// Order of resolution (first hit wins):
//   1. `type` is "cat" / "gato" / "felino"        → catSmall
//   2. `weight` is present and finite             → bucketed by weight
//   3. `breed` matches a small / medium / large lookup → that bucket
//   4. fallback                                  → dogMedium
//
// Boundaries are conservative — most working / sporting breeds are
// "medium" unless we're sure. A user can override later via the explicit
// size field once Phase 2 lands.

import '../services/activity_calculator.dart';

/// Static helper namespace.
class PetSizeInference {
  /// Infer a [PetSize] for a pet whose Firestore record may carry any
  /// subset of `type`, `breed`, `weight`. All arguments are optional;
  /// when nothing is known we default to [PetSize.dogMedium].
  static PetSize infer({String? type, String? breed, double? weightKg}) {
    final t = (type ?? '').toLowerCase().trim();
    if (_catTypes.contains(t)) return PetSize.catSmall;

    final b = (breed ?? '').toLowerCase().trim();
    if (b.isNotEmpty && _catBreedKeywords.any(b.contains)) {
      return PetSize.catSmall;
    }

    if (weightKg != null && weightKg.isFinite && weightKg > 0) {
      if (weightKg < 10) return PetSize.dogSmall;
      if (weightKg <= 25) return PetSize.dogMedium;
      return PetSize.dogLarge;
    }

    if (b.isNotEmpty) {
      if (_smallBreedKeywords.any(b.contains)) return PetSize.dogSmall;
      if (_largeBreedKeywords.any(b.contains)) return PetSize.dogLarge;
      // Anything else with a breed string we recognize-ish is medium.
      if (_mediumBreedKeywords.any(b.contains)) return PetSize.dogMedium;
    }

    return PetSize.dogMedium;
  }

  // -- Lookup tables -------------------------------------------------------

  static const Set<String> _catTypes = {'cat', 'gato', 'felino', 'feline'};
  static const List<String> _catBreedKeywords = [
    'gato',
    'felino',
    'siamés',
    'siames',
    'persa',
    'maine coon',
    'angora',
  ];

  // Substring matches — Spanish + English breed names live side by side.
  static const List<String> _smallBreedKeywords = [
    'chihuahua',
    'pomerania',
    'pomeranian',
    'yorkie',
    'yorkshire',
    'maltés',
    'maltes',
    'maltese',
    'shih tzu',
    'pug',
    'mini poodle',
    'french poodle',
    'caniche',
    'pinscher',
    'jack russell',
    'dachshund',
    'salchicha',
    'bichon',
    'bichón',
  ];
  static const List<String> _mediumBreedKeywords = [
    'labrador',
    'beagle',
    'border collie',
    'bulldog',
    'boxer',
    'cocker',
    'schnauzer',
    'mestizo',
    'mestiza',
    'criollo',
    'criolla',
    'mixed',
  ];
  static const List<String> _largeBreedKeywords = [
    'pastor alemán',
    'pastor aleman',
    'german shepherd',
    'rottweiler',
    'doberman',
    'gran danés',
    'gran danes',
    'great dane',
    'mastín',
    'mastin',
    'mastiff',
    'san bernardo',
    'akita',
    'husky',
    'malamute',
    'galgo',
    'greyhound',
    'pitbull',
    'pit bull',
    'staffordshire',
    'golden retriever',
  ];
}
