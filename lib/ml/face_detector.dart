import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class FaceDetectorService {
  late final FaceDetector _faceDetector;
  bool _isClosed = false;

  FaceDetectorService() {
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.accurate, // better accuracy
        enableLandmarks: false,
        enableContours: false,
        enableClassification: false,
        minFaceSize: 0.15,
      ),
    );
  }

  /// Detect faces from an input image
  Future<List<Face>> detectFaces(InputImage image) async {
    if (_isClosed) return [];

    try {
      return await _faceDetector.processImage(image);
    } catch (e) {
      // Prevent crash if detector is called after dispose
      return [];
    }
  }

  /// Dispose detector safely
  void dispose() {
    if (!_isClosed) {
      _faceDetector.close();
      _isClosed = true;
    }
  }
}
