/// Coarse connectivity for UI surfaces.
///
/// A collar in MODE 8 sleeps by design whenever the pet is home or
/// still — hours of silence are its NORMAL, healthy state. The old
/// binary (online/disconnected at 30 min) painted every sleeping
/// collar red, so a customer's first hours with a working product
/// looked like a broken one (reported 2026-08-02, first-day
/// onboarding). Three buckets instead of two:
///   online  — reported within the last 30 min
///   resting — quiet for 30 min..24 h: sleeping / saving battery
///   offline — silent for over 24 h (or never seen): worth worrying
enum DeviceConnectivity { online, resting, offline }

/// Device model for GPS tracker
class Device {
  final int id;
  final String name;
  final String uniqueId; // IMEI
  final int? traccarId; // Traccar device ID (null if not provisioned)
  final String status; // active, inactive, pending
  final DateTime createdAt;
  final DateTime? lastUpdate;
  final String? lastLocation;

  Device({
    required this.id,
    required this.name,
    required this.uniqueId,
    this.traccarId,
    required this.status,
    required this.createdAt,
    this.lastUpdate,
    this.lastLocation,
  });

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id'] as int,
      name: json['name'] as String,
      uniqueId: json['uniqueId'] as String,
      traccarId: json['traccarId'] as int?,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastUpdate: json['lastUpdate'] != null 
          ? DateTime.parse(json['lastUpdate'] as String)
          : null,
      lastLocation: json['lastLocation'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'uniqueId': uniqueId,
      'traccarId': traccarId,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'lastUpdate': lastUpdate?.toIso8601String(),
      'lastLocation': lastLocation,
    };
  }

  bool get isOnline => lastUpdate != null &&
      DateTime.now().difference(lastUpdate!).inMinutes < 30;

  DeviceConnectivity get connectivity {
    // Instant math is timezone-safe: difference() compares epochs, so
    // a UTC lastUpdate against a local now() still yields the true gap.
    if (lastUpdate == null) return DeviceConnectivity.offline;
    final quiet = DateTime.now().difference(lastUpdate!);
    if (quiet.inMinutes < 30) return DeviceConnectivity.online;
    if (quiet.inHours < 24) return DeviceConnectivity.resting;
    return DeviceConnectivity.offline;
  }

  String get statusText {
    switch (status) {
      case 'active':
        switch (connectivity) {
          case DeviceConnectivity.online:
            return 'En línea';
          case DeviceConnectivity.resting:
            return 'En reposo';
          case DeviceConnectivity.offline:
            return 'Desconectado';
        }
      case 'inactive':
        return 'Inactivo';
      case 'pending':
        return 'Pendiente';
      default:
        return 'Desconocido';
    }
  }

  /// Return the non-null `traccarId`, throwing a clear `StateError`
  /// with the IMEI baked into the message when it is null. Prefer this
  /// to `device.requireTraccarId()` everywhere — the bang operator's
  /// `_TypeError: Null check operator used on a null value` is
  /// impossible to attribute to a specific device, but a `StateError`
  /// from here points straight at the row that's missing its
  /// provisioning.
  ///
  /// `traccarId` is null when:
  ///   1. `provisionDevice` was called with an existing IMEI and the
  ///      backend returned the idempotent 200 path without
  ///      re-emitting credentials (the constructed Device then carries
  ///      whatever id we already had — sometimes null).
  ///   2. A pet row in Firestore is ahead of postgres / Traccar (rare
  ///      but possible during partial onboarding aborts).
  ///
  /// Callers that can recover (e.g. show a "not ready" placeholder
  /// instead of crashing) should still null-check `traccarId` directly
  /// at the call site — this helper is for paths that have no
  /// recovery and must fail loudly.
  int requireTraccarId() {
    final id = traccarId;
    if (id == null) {
      throw StateError(
        'Device $uniqueId has no Traccar ID yet (status=$status). '
        'This usually means provisioning is pending or returned the '
        'idempotent 200 path without credentials.',
      );
    }
    return id;
  }
}
