import 'dart:async';
import 'dart:ui';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../app_config.dart';
import 'location_service.dart';

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: 'attendance_channel',
      initialNotificationTitle: 'Attendance Tracking',
      initialNotificationContent: 'Initializing...',
      foregroundServiceNotificationId: 888,
    ),
  );

  await service.startService();

}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  // Initialize Firebase for background isolate
  await Firebase.initializeApp();

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  // Set foreground immediately
  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
    service.setForegroundNotificationInfo(
      title: "Attendance Active",
      content: "Starting location tracking...",
    );
  }

  await Future.delayed(const Duration(seconds: 1));

  // Check location service
  bool locationEnabled = await Geolocator.isLocationServiceEnabled();
  if (!locationEnabled) {
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: "Location Disabled",
        content: "Please enable location services",
      );
    }
    await Future.delayed(const Duration(seconds: 10));
    service.stopSelf();
    return;
  }

  // Check permission
  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }

  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: "Permission Denied",
        content: "Location permission required",
      );
    }
    await Future.delayed(const Duration(seconds: 5));
    service.stopSelf();
    return;
  }

  // Fetch office settings
  Map<String, double> officeConfig = AppConfig.defaultOfficeSettings;

  try {
    officeConfig = await LocationService.fetchOfficeSettings(forceRefresh: true);
  } catch (e) {
    print("Error fetching settings: $e");
  }

  bool isInsideOffice = false;
  StreamSubscription<Position>? positionStream;
  try {
    Position initial = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    final initialDistance = Geolocator.distanceBetween(
      officeConfig['lat']!,
      officeConfig['lng']!,
      initial.latitude,
      initial.longitude,
    );

    isInsideOffice = initialDistance <= officeConfig['radius']!;
    
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: "Location Acquired",
        content: isInsideOffice ? "Inside office area" : "Outside office area",
      );
    }

  } catch (e) {
    print("Error getting initial position: $e");
  }

  // Start continuous tracking
  positionStream = Geolocator.getPositionStream(
    locationSettings: AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
      intervalDuration: const Duration(seconds: 5),
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationText: "Your location is being tracked",
        notificationTitle: "Attendance Tracking",
        enableWakeLock: true,
      ),
    ),
  ).listen(
    (Position position) async {
      final now = DateTime.now();

      final distance = Geolocator.distanceBetween(
        officeConfig['lat']!,
        officeConfig['lng']!,
        position.latitude,
        position.longitude,
      );

      bool currentlyInside = distance <= officeConfig['radius']!;

      // ENTERED OFFICE
      if (currentlyInside && !isInsideOffice) {
        isInsideOffice = true;

        await _logMovement("IN", position);

        if (service is AndroidServiceInstance) {
          service.setForegroundNotificationInfo(
            title: "✅ Re-entered Office",
            content: "Logged at ${now.hour}:${now.minute.toString().padLeft(2, '0')}",
          );
        }
      }
      // EXITED OFFICE
      else if (!currentlyInside && isInsideOffice) {
        isInsideOffice = false;

        // Log the exit and UPDATE the main OUT time
        await _updateOutTime(position);

        if (service is AndroidServiceInstance) {
          service.setForegroundNotificationInfo(
            title: "❌ Left Office",
            content: "OUT time updated: ${now.hour}:${now.minute.toString().padLeft(2, '0')}",
          );
        }
      }
      // UPDATE STATUS
      else {
        if (service is AndroidServiceInstance) {
          String status = currentlyInside ? "Inside" : "Outside";
          service.setForegroundNotificationInfo(
            title: "📍 $status Office",
            content: "${distance.toInt()}m away • ${now.hour}:${now.minute.toString().padLeft(2, '0')}",
          );
        }
      }
    },
    onError: (error) {
      print("Location error: $error");
    },
    cancelOnError: false,
  );

  // Keep-alive heartbeat
  Timer.periodic(const Duration(minutes: 1), (timer) {
    if (service is AndroidServiceInstance) {
      final now = DateTime.now();
      service.setForegroundNotificationInfo(
        title: "Attendance Active",
        content: "Tracking... ${now.hour}:${now.minute.toString().padLeft(2, '0')}",
      );
    }
  });

  // Stop service handler
  service.on('stopService').listen((event) async {
    await positionStream?.cancel();
    service.stopSelf();
  });
}

/// Log intermediate movements (for audit trail)
Future<void> _logMovement(String type, Position position) async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final today = DateTime.now().toIso8601String().substring(0, 10);
    final docId = "${user.uid}_$today";

    await FirebaseFirestore.instance
        .collection('attendance_logs')
        .doc(docId)
        .collection('logs')
        .add({
      'type': type,
      'lat': position.latitude,
      'lng': position.longitude,
      'time': FieldValue.serverTimestamp(),
    });

    print("✅ Logged movement: $type");
  } catch (e) {
    print("❌ Error logging movement: $e");
  }
}

/// Update the OFFICIAL OUT time in the main attendance record
Future<void> _updateOutTime(Position position) async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final today = DateTime.now().toIso8601String().substring(0, 10);
    final docId = "${user.uid}_$today";

    // Update the main attendance document with latest OUT time
    await FirebaseFirestore.instance
        .collection('attendance')
        .doc(docId)
        .update({
      'outTime': FieldValue.serverTimestamp(),
      'outTimestamp': FieldValue.serverTimestamp(),
      'outLat': position.latitude,
      'outLng': position.longitude,
    });

    // Also log in movements collection for audit
    await _logMovement("OUT", position);

    print("✅ OUT time updated successfully");
  } catch (e) {
    print("❌ Error updating OUT time: $e");
  }
}
