// PetTrack Constants
class AppConstants {
  // API URLs
  static const String traccarBaseUrl = 'http://64.23.156.25:8082';
  static const String provisioningApiUrl = 'https://64.23.156.25/api';
  static const String pushServiceUrl = 'https://64.23.156.25/push';
  
  // API Endpoints
  static String get traccarApiUrl => '$traccarBaseUrl/api';
  static String get traccarWebSocketUrl => 'ws://64.23.156.25:8082/api/socket';
  
  // App Info
  static const String appName = 'PetTrack';
  static const String appVersion = '1.0.0';
  static const String supportEmail = 'soporte@pettrack.co';
  
  // Subscription Pricing (COP)
  static const int monthlyPrice = 29900;
  static const int annualPrice = 250000;
  
  // Limits (MVP)
  static const int maxPetsPerUser = 1;
  static const int maxGeofencesPerPet = 3;
  
  // Tracking
  static const int normalUpdateIntervalSeconds = 300; // 5 minutes
  static const int liveUpdateIntervalSeconds = 10; // 10 seconds
  static const int batteryLowThreshold = 20; // 20%
  
  // Map
  static const double defaultZoom = 15.0;
  static const double defaultLatitude = 4.6097; // Bogotá
  static const double defaultLongitude = -74.0817;
}
