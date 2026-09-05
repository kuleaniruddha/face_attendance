import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../ml/face_detector.dart';
import '../services/database_service.dart';
import '../services/location_service.dart';
import '../main.dart';
import '../app_config.dart';

class MarkAttendance extends StatefulWidget {
  const MarkAttendance({super.key});

  @override
  State<MarkAttendance> createState() => _MarkAttendanceState();
}

class _MarkAttendanceState extends State<MarkAttendance> {
  CameraController? _camera;

  final FaceDetectorService _faceDetector = FaceDetectorService();
  final DatabaseService _db = DatabaseService();
  final _faceNet = faceNetService;

  bool _processing = false;
  String _status = "Scan your face to start attendance";

  @override
  void initState() {
    super.initState();
    _initCamera();
    _checkExistingAttendance();
  }

  /// Check if attendance is already marked
  Future<void> _checkExistingAttendance() async {
    try {
      final attendance = await _db.getTodayAttendance();
      if (attendance != null && attendance['inTime'] != null) {
        final inTime = (attendance['inTime'] as Timestamp).toDate();
        final timeStr = "${inTime.hour}:${inTime.minute.toString().padLeft(2, '0')}";
        
        setState(() {
          _status = "✅ Attendance already marked at $timeStr";
        });
      }
    } catch (e) {
      debugPrint("Error checking attendance: $e");
    }
  }

  // ---------------- CAMERA INIT ----------------
  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
      );

      _camera = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _camera!.initialize();
      if (mounted) setState(() {});
    } catch (e) {
      _updateStatus("Camera error ❌");
    }
  }

  // ---------------- FETCH OFFICE SETTINGS ----------------
  Future<Map<String, double>> _fetchOfficeSettings() async {
    return await LocationService.fetchOfficeSettings(forceRefresh: true);
  }

  // ---------------- LOCATION CHECK ----------------
  Future<Position?> _getCurrentPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      _updateStatus("Location error: ${e.toString()}");
      return null;
    }
  }

  Future<Map<String, dynamic>> _checkOfficeLocation(Position position) async {
    final settings = await _fetchOfficeSettings();

    final distance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      settings['lat']!,
      settings['lng']!,
    );

    final allowedRadius = settings['radius']!;
    final isInside = distance <= allowedRadius;

    return {
      'isInside': isInside,
      'distance': distance,
      'allowedRadius': allowedRadius,
    };
  }

  // ---------------- FACE SCAN & MARK IN ----------------
  Future<void> scanFace() async {
    if (_processing ||
        _camera == null ||
        !_camera!.value.isInitialized) {
      return;
    }

    if (!_faceNet.isLoaded) {
      _updateStatus("❌ AI FaceNet model loading... Please wait.");
      return;
    }

    setState(() {
      _processing = true;
      _status = "Verifying location...";
    });

    try {
      // 1️⃣ GET CURRENT LOCATION
      final position = await _getCurrentPosition();
      if (position == null) return;

      // 2️⃣ GEO-FENCE CHECK
      final locCheck = await _checkOfficeLocation(position);
      final bool isInside = locCheck['isInside'];
      final double distanceMeters = locCheck['distance'];
      final double radiusMeters = locCheck['allowedRadius'];

      if (!isInside) {
        final distStr = distanceMeters >= 1000
            ? "${(distanceMeters / 1000).toStringAsFixed(2)} km"
            : "${distanceMeters.toStringAsFixed(0)} m";
        final radiusStr = radiusMeters >= 1000
            ? "${(radiusMeters / 1000).toStringAsFixed(2)} km"
            : "${radiusMeters.toStringAsFixed(0)} m";

        _updateStatus("❌ Outside office area ($distStr away, allowed max: $radiusStr)");
        return;
      }

      // 3️⃣ CHECK ALREADY MARKED
      if (await _db.isAttendanceMarkedToday()) {
        _updateStatus("✅ Attendance already started today");
        return;
      }

      _updateStatus("📸 Scanning face...");

      // 4️⃣ CAPTURE IMAGE
      final XFile pic = await _camera!.takePicture();
      final Uint8List imageBytes = await pic.readAsBytes();
      final inputImage = InputImage.fromFilePath(pic.path);

      final faces = await _faceDetector.detectFaces(inputImage);
      if (faces.isEmpty) {
        _updateStatus("❌ No face detected. Adjust lighting and angle.");
        return;
      }
      if (faces.length > 1) {
        _updateStatus("❌ Only one face allowed in frame.");
        return;
      }

      _updateStatus("🔍 Verifying face identity...");

      // 5️⃣ FACE MATCH
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final storedEmbedding = await _db.getStoredEmbedding(uid);

      if (storedEmbedding == null) {
        _updateStatus("❌ Face not registered. Please register your face first.");
        return;
      }

      final liveEmbedding =
          await _faceNet.generateEmbedding(imageBytes, faces.first);

      if (liveEmbedding.isEmpty) {
        _updateStatus("❌ Could not generate face features.");
        return;
      }

      final similarity =
          _faceNet.cosineSimilarity(liveEmbedding, storedEmbedding);

      if (similarity < AppConfig.faceMatchThreshold) {
        _updateStatus("❌ Face match failed (${(similarity * 100).toStringAsFixed(1)}%)");
        return;
      }

      _updateStatus("✅ Face verified! Marking attendance...");

      // 6️⃣ MARK IN TIME (creates the main record)
      await _db.markFirstIn();

      // 7️⃣ UPDATE IN LOCATION
      await _db.updateInLocation(position.latitude, position.longitude);

      // 8️⃣ START BACKGROUND LOCATION TRACKING
      await LocationService.startAttendanceTracking();

      final now = DateTime.now();
      final timeStr = "${now.hour}:${now.minute.toString().padLeft(2, '0')}";
      
      _updateStatus("✅ Attendance marked at $timeStr");

      // Show success dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.white,
            title: const Text(
              "Success",
              style: TextStyle(color: Color(0xFF15803D)),
            ),
            content: Text(
              "Attendance marked successfully at $timeStr\n\n"
              "Background tracking is now active.",
              style: const TextStyle(color: Color(0xFF334155)),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop(); // Go back to dashboard
                },
                child: const Text("OK"),
              ),
            ],
          ),
        );
      }

    } catch (e) {
      _updateStatus("❌ Error: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  void _updateStatus(String text) {
    if (mounted) setState(() => _status = text);
  }

  @override
  void dispose() {
    _camera?.dispose();
    _faceDetector.dispose();
    super.dispose();
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    if (_camera == null || !_camera!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Color(0xFFF7F9FC),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text("Mark Attendance"),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // CAMERA
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF0B5CAD), width: 2),
              ),
              clipBehavior: Clip.antiAlias,
              child: AspectRatio(
                aspectRatio: 3 / 4,
                child: CameraPreview(_camera!),
              ),
            ),

            const SizedBox(height: 24),

            // STATUS
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  if (_processing)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF0B5CAD),
                      ),
                    ),
                  if (_processing) const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _status,
                      style: const TextStyle(
                        color: Color(0xFF334155),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // BUTTON
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                icon: _processing
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.face_unlock_outlined),
                label: Text(
                  _processing ? "PROCESSING..." : "SCAN FACE TO START",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                onPressed: _processing ? null : scanFace,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0B5CAD),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // INFO TEXT
            const Text(
              "Position yourself in good lighting\nLook directly at the camera",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
