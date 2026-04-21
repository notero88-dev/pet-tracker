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

  String get statusText {
    switch (status) {
      case 'active':
        return isOnline ? 'En línea' : 'Desconectado';
      case 'inactive':
        return 'Inactivo';
      case 'pending':
        return 'Pendiente';
      default:
        return 'Desconocido';
    }
  }
}
