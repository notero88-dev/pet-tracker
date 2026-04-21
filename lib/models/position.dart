/// GPS Position from Traccar
class Position {
  final int id;
  final int deviceId;
  final DateTime deviceTime; // GPS time
  final DateTime serverTime; // Received time
  final double latitude;
  final double longitude;
  final double? altitude;
  final double? speed; // km/h
  final double? course; // degrees 0-360
  final double? accuracy; // meters
  final String? address;
  final Map<String, dynamic>? attributes; // Extra data (battery, etc.)

  Position({
    required this.id,
    required this.deviceId,
    required this.deviceTime,
    required this.serverTime,
    required this.latitude,
    required this.longitude,
    this.altitude,
    this.speed,
    this.course,
    this.accuracy,
    this.address,
    this.attributes,
  });

  factory Position.fromJson(Map<String, dynamic> json) {
    return Position(
      id: json['id'] as int,
      deviceId: json['deviceId'] as int,
      deviceTime: DateTime.parse(json['deviceTime'] as String),
      serverTime: DateTime.parse(json['serverTime'] as String),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      altitude: json['altitude'] != null 
          ? (json['altitude'] as num).toDouble() 
          : null,
      speed: json['speed'] != null 
          ? (json['speed'] as num).toDouble() 
          : null,
      course: json['course'] != null 
          ? (json['course'] as num).toDouble() 
          : null,
      accuracy: json['accuracy'] != null 
          ? (json['accuracy'] as num).toDouble() 
          : null,
      address: json['address'] as String?,
      attributes: json['attributes'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'deviceId': deviceId,
      'deviceTime': deviceTime.toIso8601String(),
      'serverTime': serverTime.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
      'speed': speed,
      'course': course,
      'accuracy': accuracy,
      'address': address,
      'attributes': attributes,
    };
  }

  /// Battery level (0-100) from attributes
  int? get batteryLevel {
    if (attributes == null) return null;
    final battery = attributes!['batteryLevel'];
    if (battery == null) return null;
    return (battery as num).toInt();
  }

  /// Check if position is recent (< 10 minutes old)
  bool get isRecent {
    return DateTime.now().difference(deviceTime).inMinutes < 10;
  }

  /// Format speed for display
  String get speedText {
    if (speed == null) return 'N/A';
    return '${speed!.toStringAsFixed(1)} km/h';
  }

  /// Format coordinates for display
  String get coordinatesText {
    return '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
  }
}
