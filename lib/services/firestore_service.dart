import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Firestore service for user and pet profile management
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Get current user ID
  String? get _currentUserId => _auth.currentUser?.uid;

  /// Upload a pet photo to Firebase Storage and return its download URL.
  ///
  /// Path: `pet_photos/{uid}/{millisSinceEpoch}.jpg`. The timestamp keeps
  /// successive photos for the same pet from overwriting each other (the
  /// caller stores the returned URL on the pet doc; old objects are
  /// orphaned but harmless — a future cleanup job can prune them).
  ///
  /// Returns null on any failure (no auth, upload error) so callers can
  /// proceed without a photo rather than blocking onboarding on it.
  Future<String?> uploadPetPhoto(File file) async {
    final uid = _currentUserId;
    if (uid == null) return null;
    try {
      final ref = _storage
          .ref()
          .child('pet_photos')
          .child(uid)
          .child('${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putFile(
        file,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      return await ref.getDownloadURL();
    } catch (_) {
      return null;
    }
  }

  // ==================== USER PROFILES ====================

  /// Create or update user profile
  Future<void> saveUserProfile({
    required String userId,
    required String email,
    String? displayName,
    String? phone,
    String? photoUrl,
  }) async {
    await _db.collection('users').doc(userId).set({
      'email': email,
      'displayName': displayName,
      'phone': phone,
      'photoUrl': photoUrl,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Get user profile.
  ///
  /// **Source: server (with cache fallback).** Forced to bypass Firestore's
  /// iOS local persistence after the 2026-05-23 incident where a stale
  /// cached doc (predating the addition of `traccarEmail` /
  /// `traccarPassword` fields) kept causing the app's Mapa tab to render
  /// empty even though the server-side Firestore doc had everything.
  ///
  /// The trap is silent: when `_initializeTraccar` reads a doc without
  /// `traccarPassword`, it `debugPrint`s and early-returns. The user sees
  /// "Aún no hay mascotas" with no error toast and no recovery path
  /// except deleting + reinstalling the app to wipe the Firestore
  /// persistence file in the iOS sandbox.
  ///
  /// First try `Source.server`. On any error (network out, timeout, etc.)
  /// fall back to default `Source.serverAndCache` so an offline launch
  /// still gets the cached profile. This preserves offline-launch UX
  /// while killing the stale-cache trap that was costing live users.
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    final ref = _db.collection('users').doc(userId);
    try {
      final fresh = await ref.get(const GetOptions(source: Source.server));
      return fresh.exists ? fresh.data() : null;
    } catch (_) {
      // Network failure, timeout, etc. — fall back to whatever's local
      // so offline-first launches still work.
      final cached = await ref.get();
      return cached.exists ? cached.data() : null;
    }
  }

  /// Update user profile fields. Uses `set` + merge instead of `update` so it
  /// creates the doc if it doesn't yet exist (avoids `cloud_firestore/not-found`
  /// errors). This is the right behavior for users whose Firebase Auth account
  /// predates the version of the app that calls saveUserProfile() at signup —
  /// e.g. accounts created during early prototyping or directly via Firebase
  /// Console. Behaves identically to `update` for users who already have a doc.
  Future<void> updateUserProfile(String userId, Map<String, dynamic> updates) async {
    updates['updatedAt'] = FieldValue.serverTimestamp();
    await _db.collection('users').doc(userId).set(updates, SetOptions(merge: true));
  }

  // ==================== PET PROFILES ====================

  /// Create pet profile
  Future<String> createPet({
    required String name,
    required String type,
    String? breed,
    double? weight,
    String? photoUrl,
    String? notes,
    int? traccarDeviceId,
    String? deviceImei,
  }) async {
    if (_currentUserId == null) throw Exception('No authenticated user');

    final petRef = await _db.collection('pets').add({
      'userId': _currentUserId,
      'name': name,
      'type': type,
      'breed': breed,
      'weight': weight,
      'photoUrl': photoUrl,
      'notes': notes,
      'traccarDeviceId': traccarDeviceId,
      'deviceImei': deviceImei,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return petRef.id;
  }

  /// Get all pets for current user.
  ///
  /// We DON'T order on the Firestore side (`orderBy('createdAt')`) because
  /// that combined with `where('userId')` requires a composite index —
  /// see the failed-precondition we hit 2026-05-11 on the activity screen.
  /// Pets-per-user is small (typically 1–3), so client-side sorting is
  /// effectively free and removes the index dependency for all users.
  Future<List<Map<String, dynamic>>> getUserPets() async {
    if (_currentUserId == null) return [];

    // Server-first with cache fallback. Same rationale as getUserProfile
    // (see 2026-05-23 fix): the SDK's default behavior returns whatever
    // is in the offline cache when the cache is "fresh enough," which
    // can be stale by days. We hit "Aún no hay mascotas" empty state on
    // accounts where a pet was just created via a different surface
    // (script, admin tool, second device). Force a server hit; on
    // network failure fall back to whatever the cache has so offline
    // launches still render the previously-seen pets.
    final query = _db
        .collection('pets')
        .where('userId', isEqualTo: _currentUserId);
    QuerySnapshot<Map<String, dynamic>> snapshot;
    try {
      snapshot = await query.get(const GetOptions(source: Source.server));
    } catch (_) {
      snapshot = await query.get();
    }

    final pets = snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();

    // Sort ascending by createdAt. Tolerate missing/non-Timestamp values
    // by treating them as epoch-min so they sort first instead of throwing.
    pets.sort((a, b) {
      final aRaw = a['createdAt'];
      final bRaw = b['createdAt'];
      final aTime = aRaw is Timestamp ? aRaw.toDate() : DateTime.utc(1970);
      final bTime = bRaw is Timestamp ? bRaw.toDate() : DateTime.utc(1970);
      return aTime.compareTo(bTime);
    });

    return pets;
  }

  /// Get pet by ID
  Future<Map<String, dynamic>?> getPet(String petId) async {
    final doc = await _db.collection('pets').doc(petId).get();
    if (doc.exists) {
      final data = doc.data();
      data?['id'] = doc.id;
      return data;
    }
    return null;
  }

  /// Update pet profile
  Future<void> updatePet(String petId, Map<String, dynamic> updates) async {
    updates['updatedAt'] = FieldValue.serverTimestamp();
    await _db.collection('pets').doc(petId).update(updates);
  }

  /// Delete pet
  Future<void> deletePet(String petId) async {
    await _db.collection('pets').doc(petId).delete();
  }

  /// One-shot cleanup: deduplicate pet docs that point to the same
  /// `traccarDeviceId`. For each duplicate group, keeps the row with the
  /// most-recent `createdAt` and deletes the rest. Returns the number of
  /// docs deleted.
  ///
  /// Why: between 2026-04 and 2026-05 our provisioning flow created a new
  /// Firestore pet doc on every onboarding attempt, including retries.
  /// Verified 2026-05-11 — a single test user had 6 docs all named
  /// "test_1"/"TEST_1" pointing to the same traccarDeviceId. The activity
  /// dashboard's pet picker rendered 6 near-identical pills, only one of
  /// them showing real data. This routine is idempotent — safe to call
  /// on every app launch; no-op when there are no duplicates.
  ///
  /// Does NOT touch pets where `traccarDeviceId` is null or non-int —
  /// those rows are kept individually (they may be incomplete provisioning
  /// attempts the user wants to retry).
  Future<int> dedupePetsByDevice() async {
    if (_currentUserId == null) return 0;
    final pets = await getUserPets();
    if (pets.length <= 1) return 0;

    // Group by traccarDeviceId; skip rows without one.
    final byDeviceId = <int, List<Map<String, dynamic>>>{};
    for (final pet in pets) {
      final id = pet['traccarDeviceId'];
      if (id is! int) continue;
      byDeviceId.putIfAbsent(id, () => []).add(pet);
    }

    var deletedCount = 0;
    for (final entry in byDeviceId.entries) {
      final group = entry.value;
      if (group.length <= 1) continue;
      // Sort descending by createdAt — most recent first.
      group.sort((a, b) {
        final aT = a['createdAt'];
        final bT = b['createdAt'];
        final aTime = aT is Timestamp ? aT.toDate() : DateTime.utc(1970);
        final bTime = bT is Timestamp ? bT.toDate() : DateTime.utc(1970);
        return bTime.compareTo(aTime);
      });
      // Keep group[0]; delete the rest.
      for (var i = 1; i < group.length; i++) {
        final docId = group[i]['id'] as String?;
        if (docId == null) continue;
        try {
          await _db.collection('pets').doc(docId).delete();
          deletedCount++;
        } catch (e) {
          // Don't let one failed delete kill the whole sweep — log and
          // continue. Next launch will retry.
          // ignore: avoid_print
          print('[dedupePetsByDevice] failed to delete $docId: $e');
        }
      }
    }
    return deletedCount;
  }

  /// Link device to pet
  Future<void> linkDeviceToPet({
    required String petId,
    required int traccarDeviceId,
    required String deviceImei,
  }) async {
    await _db.collection('pets').doc(petId).update({
      'traccarDeviceId': traccarDeviceId,
      'deviceImei': deviceImei,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ==================== GEOFENCES ====================

  /// Create geofence
  Future<String> createGeofence({
    required String petId,
    required String name,
    required double latitude,
    required double longitude,
    required double radius,
    String? notes,
  }) async {
    if (_currentUserId == null) throw Exception('No authenticated user');

    final geofenceRef = await _db.collection('geofences').add({
      'userId': _currentUserId,
      'petId': petId,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'radius': radius,
      'notes': notes,
      'enabled': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return geofenceRef.id;
  }

  /// Get geofences for a pet
  Future<List<Map<String, dynamic>>> getPetGeofences(String petId) async {
    final snapshot = await _db
        .collection('geofences')
        .where('petId', isEqualTo: petId)
        .where('enabled', isEqualTo: true)
        .orderBy('createdAt', descending: false)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  /// Update geofence
  Future<void> updateGeofence(String geofenceId, Map<String, dynamic> updates) async {
    updates['updatedAt'] = FieldValue.serverTimestamp();
    await _db.collection('geofences').doc(geofenceId).update(updates);
  }

  /// Delete geofence
  Future<void> deleteGeofence(String geofenceId) async {
    await _db.collection('geofences').doc(geofenceId).update({
      'enabled': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ==================== SUBSCRIPTIONS ====================
  //
  // 2026-05-25: removed Firestore-side subscription CRUD
  // (createSubscription / getActiveSubscription / cancelSubscription)
  // along with the orphan Wompi-tagged shape. Subscription state
  // is now owned by the Postgres `subscriptions` table on the
  // backend, fed by Apple ASSN / Google Play RTDN webhooks. The
  // app reads it via SubscriptionApi → /api/subscriptions/me, not
  // Firestore. See lib/services/subscription_api.dart +
  // lib/providers/subscription_provider.dart.
  //
  // The Firestore `subscriptions` collection itself still exists on
  // the server (cheap to leave; nobody writes to it anymore) but
  // we'll clean it up in a follow-up housekeeping commit.

  // ==================== NOTIFICATIONS ====================

  /// Save FCM token for push notifications
  Future<void> saveFcmToken(String token) async {
    if (_currentUserId == null) return;

    await _db.collection('users').doc(_currentUserId).update({
      'fcmToken': token,
      'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Get notification preferences
  Future<Map<String, dynamic>?> getNotificationPreferences() async {
    if (_currentUserId == null) return null;

    final doc = await _db
        .collection('users')
        .doc(_currentUserId)
        .collection('settings')
        .doc('notifications')
        .get();

    return doc.exists ? doc.data() : null;
  }

  /// Update notification preferences
  Future<void> updateNotificationPreferences(Map<String, dynamic> preferences) async {
    if (_currentUserId == null) return;

    preferences['updatedAt'] = FieldValue.serverTimestamp();
    await _db
        .collection('users')
        .doc(_currentUserId)
        .collection('settings')
        .doc('notifications')
        .set(preferences, SetOptions(merge: true));
  }
}
