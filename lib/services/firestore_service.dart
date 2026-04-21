import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Firestore service for user and pet profile management
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get current user ID
  String? get _currentUserId => _auth.currentUser?.uid;

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

  /// Get user profile
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    final doc = await _db.collection('users').doc(userId).get();
    return doc.exists ? doc.data() : null;
  }

  /// Update user profile field
  Future<void> updateUserProfile(String userId, Map<String, dynamic> updates) async {
    updates['updatedAt'] = FieldValue.serverTimestamp();
    await _db.collection('users').doc(userId).update(updates);
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

  /// Get all pets for current user
  Future<List<Map<String, dynamic>>> getUserPets() async {
    if (_currentUserId == null) return [];

    final snapshot = await _db
        .collection('pets')
        .where('userId', isEqualTo: _currentUserId)
        .orderBy('createdAt', descending: false)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
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

  /// Create subscription
  Future<String> createSubscription({
    required String plan, // 'monthly' or 'annual'
    required String paymentMethod,
    String? wompiTransactionId,
  }) async {
    if (_currentUserId == null) throw Exception('No authenticated user');

    final now = DateTime.now();
    final endDate = plan == 'annual'
        ? now.add(Duration(days: 365))
        : now.add(Duration(days: 30));

    final subRef = await _db.collection('subscriptions').add({
      'userId': _currentUserId,
      'plan': plan,
      'status': 'active',
      'startDate': now,
      'endDate': endDate,
      'paymentMethod': paymentMethod,
      'wompiTransactionId': wompiTransactionId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return subRef.id;
  }

  /// Get active subscription for current user
  Future<Map<String, dynamic>?> getActiveSubscription() async {
    if (_currentUserId == null) return null;

    final snapshot = await _db
        .collection('subscriptions')
        .where('userId', isEqualTo: _currentUserId)
        .where('status', isEqualTo: 'active')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;

    final data = snapshot.docs.first.data();
    data['id'] = snapshot.docs.first.id;
    return data;
  }

  /// Cancel subscription
  Future<void> cancelSubscription(String subscriptionId) async {
    await _db.collection('subscriptions').doc(subscriptionId).update({
      'status': 'cancelled',
      'cancelledAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

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
