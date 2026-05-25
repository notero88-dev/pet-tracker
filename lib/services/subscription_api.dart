// SubscriptionApi — thin HTTP client around the provisioning-api's
// subscription endpoints. Lives alongside provisioning_api.dart and
// uses the same Firebase ID-token auth pattern.
//
// Two endpoints today:
//   GET  /api/subscriptions/me              → fetch current state
//   POST /api/subscriptions/verify-purchase → tell server the IAP succeeded
//
// Both require a Firebase ID token in the Authorization header. The
// _authHeaders() helper fetches a fresh token from FirebaseAuth on
// every call (the SDK caches + auto-refreshes internally).

import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../utils/constants.dart';

/// Server-side projection of the `subscriptions` row.
///
/// Mirrors the JSON shape returned by both `/me` and `/verify-purchase`
/// so we can use one parser. Null fields mean "not applicable for this
/// status" (e.g. `trialEndAt` is only set while status == in_trial).
class Subscription {
  final String id;
  final String status;
  final String planType;
  final int priceCop;
  final String provider;
  final String? providerProductId;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? trialEndAt;
  final DateTime? nextRenewalAt;
  final bool autoRenew;
  final DateTime? cancelledAt;
  final String? cancellationReason;

  const Subscription({
    required this.id,
    required this.status,
    required this.planType,
    required this.priceCop,
    required this.provider,
    this.providerProductId,
    this.startDate,
    this.endDate,
    this.trialEndAt,
    this.nextRenewalAt,
    required this.autoRenew,
    this.cancelledAt,
    this.cancellationReason,
  });

  /// "Live" = grants access. Mirrors the backend's
  /// `subscriptionsRepo.getActiveByCustomer()` definition: any of
  /// active / in_trial / billing_issue. The backend also gates on
  /// `end_date >= today`, which we trust here (if the server returned
  /// the row it satisfied that filter).
  bool get isLive =>
      status == 'active' || status == 'in_trial' || status == 'billing_issue';

  bool get isInTrial => status == 'in_trial';
  bool get isExpired => status == 'expired';

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  factory Subscription.fromJson(Map<String, dynamic> j) => Subscription(
        id: j['id'] as String,
        status: j['status'] as String,
        planType: j['planType'] as String,
        priceCop: (j['priceCop'] as num).toInt(),
        provider: j['provider'] as String,
        providerProductId: j['providerProductId'] as String?,
        startDate: _parseDate(j['startDate']),
        endDate: _parseDate(j['endDate']),
        trialEndAt: _parseDate(j['trialEndAt']),
        nextRenewalAt: _parseDate(j['nextRenewalAt']),
        autoRenew: (j['autoRenew'] as bool?) ?? true,
        cancelledAt: _parseDate(j['cancelledAt']),
        cancellationReason: j['cancellationReason'] as String?,
      );
}

class SubscriptionApi {
  final http.Client _http;
  final String baseUrl;

  SubscriptionApi({http.Client? httpClient})
      : _http = httpClient ?? http.Client(),
        baseUrl = AppConstants.provisioningApiUrl;

  Future<Map<String, String>> _authHeaders() async {
    final user = FirebaseAuth.instance.currentUser;
    final token = await user?.getIdToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Fetch the calling user's live subscription, or `null` if they
  /// don't have one (paywall should fire).
  ///
  /// Backend returns `{ "subscription": {...} | null }`.
  Future<Subscription?> getMe() async {
    final res = await _http.get(
      Uri.parse('$baseUrl/subscriptions/me'),
      headers: await _authHeaders(),
    );
    if (res.statusCode != 200) {
      throw SubscriptionApiException(
        statusCode: res.statusCode,
        message: 'GET /subscriptions/me failed: ${res.body}',
      );
    }
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    final sub = j['subscription'];
    if (sub == null) return null;
    return Subscription.fromJson(sub as Map<String, dynamic>);
  }

  /// Tell the backend the IAP sheet completed successfully. Backend
  /// verifies the receipt with Apple/Google + writes/upserts the
  /// subscriptions row + returns the canonical state.
  ///
  /// On iOS we pass the StoreKit 2 `signedTransactionInfo` JWT from
  /// `purchaseDetails.verificationData.serverVerificationData`.
  /// On Android, the v1 backend returns 501 — Phase B2 / Phase C
  /// follow-up wires that up.
  Future<Subscription> verifyPurchase({
    required String provider,
    required String productId,
    required String signedTransactionInfo,
  }) async {
    final res = await _http.post(
      Uri.parse('$baseUrl/subscriptions/verify-purchase'),
      headers: await _authHeaders(),
      body: jsonEncode({
        'provider': provider,
        'productId': productId,
        'signedTransactionInfo': signedTransactionInfo,
      }),
    );
    if (res.statusCode != 200) {
      throw SubscriptionApiException(
        statusCode: res.statusCode,
        message: 'POST /subscriptions/verify-purchase failed: ${res.body}',
      );
    }
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    return Subscription.fromJson(j['subscription'] as Map<String, dynamic>);
  }
}

class SubscriptionApiException implements Exception {
  final int statusCode;
  final String message;
  SubscriptionApiException({required this.statusCode, required this.message});

  @override
  String toString() => 'SubscriptionApiException($statusCode): $message';
}
