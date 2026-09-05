class AppConfig {
  static const String appTitle = 'XIE Face Attendance';
  static const String instituteName = 'Xavier Institute of Engineering';
  static const String logoAsset = 'assets/images/Screenshot 2026-08-24 112218.png';

  static const double officeLatitude = 19.044953;
  static const double officeLongitude = 72.841567;

  // Allowed attendance geofence radius (5000 meters / 5 km)
  static const double officeRadiusMeters = 5000.0;
  static const double faceMatchThreshold = 0.55;

  static const Map<String, double> defaultOfficeSettings = {
    'lat': officeLatitude,
    'lng': officeLongitude,
    'radius': officeRadiusMeters,
  };
}
