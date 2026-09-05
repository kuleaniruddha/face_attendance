import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../ml/face_detector.dart';
import '../ml/facenet_service.dart';
import '../main.dart';

class RegisterFace extends StatefulWidget {
  const RegisterFace({super.key});

  @override
  State<RegisterFace> createState() => _RegisterFaceState();
}

class _RegisterFaceState extends State<RegisterFace> {
  CameraController? _camera;
  final FaceDetectorService _faceDetector = FaceDetectorService();
  final FaceNetService _faceNet = faceNetService;

  bool _processing = false;
  final String uid = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    final frontCamera =
        cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.front);

    _camera = CameraController(
      frontCamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await _camera!.initialize();
    if (mounted) setState(() {});
  }

  Future<void> registerFace() async {
    if (_processing || _camera == null || !_camera!.value.isInitialized) return;

    if (!_faceNet.isLoaded) {
      _show("❌ AI FaceNet model is not loaded yet. Please try again.");
      return;
    }

    setState(() => _processing = true);

    try {
      final XFile file = await _camera!.takePicture();
      final Uint8List imageBytes = await file.readAsBytes();
      final inputImage = InputImage.fromFilePath(file.path);

      final faces = await _faceDetector.detectFaces(inputImage);
      if (faces.isEmpty) {
        _show("⚠️ No face detected. Position yourself clearly in frame.");
        return;
      }
      if (faces.length > 1) {
        _show("⚠️ Multiple faces detected. Ensure ONLY your face is in frame.");
        return;
      }

      final embedding =
          await _faceNet.generateEmbedding(imageBytes, faces.first);

      if (embedding.isEmpty) {
        _show("❌ Face embedding failed. Try with better lighting.");
        return;
      }

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'faceEmbedding': embedding,
        'faceEmbeddingModel': 'mobilefacenet',
        'faceEmbeddingSize': embedding.length,
        'faceRegistered': true,
        'registeredAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _show("✅ Face Registered Successfully");
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _show("❌ Error: $e");
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  void _show(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF0F172A),
        content: Text(msg),
      ),
    );
  }

  @override
  void dispose() {
    _camera?.dispose();
    _faceDetector.dispose();
    super.dispose();
  }

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

      /// APP BAR
      appBar: AppBar(
        title: const Text("Register Face"),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            /// CAMERA CARD
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.6),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
                border: Border.all(
                  color: const Color(0xFF0B5CAD).withOpacity(0.6),
                  width: 1.5,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: AspectRatio(
                aspectRatio: 3 / 4,
                child: ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.center,
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _camera!.value.previewSize!.height,
                        height: _camera!.value.previewSize!.width,
                        child: CameraPreview(_camera!),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            /// INSTRUCTION CARD
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Color(0xFF0B5CAD)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Ensure good lighting and keep only your face inside the frame.",
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            /// REGISTER BUTTON
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
                    : const Icon(Icons.face),
                label: Text(
                  _processing ? "Registering..." : "Register Face",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onPressed: _processing ? null : registerFace,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0B5CAD),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
