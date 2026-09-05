import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../app_config.dart';

class LocationService {
  static StreamSubscription<Position>? _positionStream;
  static Position? cachedPosition;

  static bool _isInsideOffice = false;
  static bool _initializedFence = false;
  static DateTime? _lastExitTime;

  static Map<String, double>? _cachedOfficeSettings;

  /// 🔹 CLEAR CACHE (CALL AFTER ADMIN UPDATES OFFICE LOCATION)
  static void clearCache() {
    _cachedOfficeSettings = null;
  }

  /// 🔹 INIT — CALL ON APP START / SPLASH
  static Future<void> init() async {
    // 🔥 Check location service
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      return;
    }

    // 🔥 Permission
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    cachedPosition = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  /// 🔹 START TRACKING — CALL AFTER FACE VERIFIED / LOGIN
  static Future<void> startAttendanceTracking() async {
    await stopAttendanceTracking();

    final settings = await fetchOfficeSettings();

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 10,
      ),
    ).listen((position) async {
      cachedPosition = position;

      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        settings['lat']!,
        settings['lng']!,
      );

      final inside = distance <= settings['radius']!;

      /// 🔹 INITIAL STATE (APP START / REOPEN)
      if (!_initializedFence) {
        _initializedFence = true;
        _isInsideOffice = inside;

        if (inside && !await _hasTodayEntry()) {
          await _logMovement("IN", position);
        }

        return;
      }

      /// 🔹 ENTER OFFICE
      if (inside && !_isInsideOffice) {
        _isInsideOffice = true;
        await _logMovement("IN", position);
      }

      /// 🔹 EXIT OFFICE (ANTI-FALSE EXIT)
      if (!inside && _isInsideOffice) {
        final now = DateTime.now();

        if (_lastExitTime == null ||
            now.difference(_lastExitTime!).inMinutes >= 2) {
          _lastExitTime = now;
          _isInsideOffice = false;
          await _logMovement("OUT", position);
        }
      }
    });
  }

  /// 🔹 STOP TRACKING — LOGOUT
  static Future<void> stopAttendanceTracking() async {
    await _positionStream?.cancel();
    _positionStream = null;
    _initializedFence = false;
    _lastExitTime = null;
  }

  /// 🔹 FETCH OFFICE SETTINGS (CACHED WITH FALLBACK & DUAL SCHEMA SUPPORT)
  static Future<Map<String, double>> fetchOfficeSettings({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedOfficeSettings != null) {
      return _cachedOfficeSettings!;
    }

    try {
      // 1. Check settings/attendance
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('attendance')
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final lat = (data['officeLat'] ?? data['lat']) as num?;
        final lng = (data['officeLng'] ?? data['lng']) as num?;
        final radius = (data['allowedRadius'] ?? data['radius']) as num?;

        if (lat != null && lng != null && radius != null) {
          _cachedOfficeSettings = {
            'lat': lat.toDouble(),
            'lng': lng.toDouble(),
            'radius': radius.toDouble(),
          };
          return _cachedOfficeSettings!;
        }
      }

      // 2. Fallback to office_locations collection
      final locSnapshot = await FirebaseFirestore.instance
          .collection('office_locations')
          .limit(1)
          .get();

      if (locSnapshot.docs.isNotEmpty) {
        final data = locSnapshot.docs.first.data();
        final lat = (data['lat'] ?? data['officeLat']) as num?;
        final lng = (data['lng'] ?? data['officeLng']) as num?;
        final radius = (data['radius'] ?? data['allowedRadius']) as num?;

        if (lat != null && lng != null && radius != null) {
          _cachedOfficeSettings = {
            'lat': lat.toDouble(),
            'lng': lng.toDouble(),
            'radius': radius.toDouble(),
          };
          return _cachedOfficeSettings!;
        }
      }
    } catch (_) {
      // Fall through to default settings
    }

    _cachedOfficeSettings = AppConfig.defaultOfficeSettings;
    return _cachedOfficeSettings!;
  }

  /// 🔹 CHECK IF TODAY ENTRY EXISTS
  static Future<bool> _hasTodayEntry() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final today = DateTime.now().toIso8601String().substring(0, 10);
    final docId = "${user.uid}_$today";

    final snapshot = await FirebaseFirestore.instance
        .collection('attendance_logs')
        .doc(docId)
        .collection('logs')
        .limit(1)
        .get();

    return snapshot.docs.isNotEmpty;
  }

  /// 🔹 LOG MOVEMENT
  static Future<void> _logMovement(
    String type,
    Position position,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final uid = user.uid;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final docId = "${uid}_$today";

    await FirebaseFirestore.instance
        .collection('attendance_logs')
        .doc(docId)
        .collection('logs')
        .add({
      'type': type, // IN / OUT
      'lat': position.latitude,
      'lng': position.longitude,
      'time': FieldValue.serverTimestamp(),
    });
  }
}
