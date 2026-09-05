import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class FaceNetService {
  // ===============================
  // MOBILEFACENET CONSTANTS
  // ===============================
  static const int inputSize = 112;     // REQUIRED
  static const int embeddingSize = 192; // REQUIRED

  Interpreter? _interpreter;
  bool _modelLoaded = false;

  bool get isLoaded => _modelLoaded;

  // ===============================
  // INIT MODEL
  // ===============================
  Future<void> init() async {
    if (_modelLoaded) return;

    try {
      _interpreter = await Interpreter.fromAsset(
        'assets/models/mobilefacenet.tflite', // ✅ FIXED PATH
        options: InterpreterOptions()..threads = 4,
      );

      final inputShape = _interpreter!.getInputTensor(0).shape;
      final outputShape = _interpreter!.getOutputTensor(0).shape;

      debugPrint("🧠 Input shape  : $inputShape");
      debugPrint("🧠 Output shape : $outputShape");

      _modelLoaded = true;
      debugPrint("✅ MobileFaceNet model loaded successfully");
    } catch (e) {
      debugPrint("❌ Failed to load model: $e");
    }
  }

  // ===============================
  // GENERATE FACE EMBEDDING
  // ===============================
  Future<List<double>> generateEmbedding(
    Uint8List imageBytes,
    Face face,
  ) async {
    if (!_modelLoaded || _interpreter == null) {
      debugPrint("❌ FaceNet model not loaded");
      return [];
    }

    img.Image? image = img.decodeImage(imageBytes);
    if (image == null) return [];

    // ===============================
    // BAKE EXIF ORIENTATION
    // ===============================
    image = img.bakeOrientation(image);

    // ===============================
    // SAFE FACE CROP
    // ===============================
    final rect = face.boundingBox;
    const double padding = 20;

    final int x = (rect.left - padding).toInt().clamp(0, image.width - 1);
    final int y = (rect.top - padding).toInt().clamp(0, image.height - 1);
    final int w =
        (rect.width + padding * 2).toInt().clamp(1, image.width - x);
    final int h =
        (rect.height + padding * 2).toInt().clamp(1, image.height - y);

    final img.Image cropped =
        img.copyCrop(image, x: x, y: y, width: w, height: h);

    final img.Image resized =
        img.copyResize(cropped, width: inputSize, height: inputSize);

    // ===============================
    // NORMALIZE IMAGE
    // ===============================
    final Float32List inputBuffer =
        Float32List(inputSize * inputSize * 3);

    int index = 0;
    for (int y = 0; y < inputSize; y++) {
      for (int x = 0; x < inputSize; x++) {
        final pixel = resized.getPixel(x, y);
        inputBuffer[index++] = (pixel.r - 128) / 128;
        inputBuffer[index++] = (pixel.g - 128) / 128;
        inputBuffer[index++] = (pixel.b - 128) / 128;
      }
    }

    final int actualEmbeddingSize =
        _interpreter!.getOutputTensor(0).shape.last;

    final output =
        List.generate(1, (_) => List.filled(actualEmbeddingSize, 0.0));

    _interpreter!.run(
      inputBuffer.reshape([1, inputSize, inputSize, 3]),
      output,
    );

    return output[0];
  }

  // ===============================
  // COSINE SIMILARITY
  // ===============================
  double cosineSimilarity(List<double> a, List<double> b) {
    if (a.isEmpty || b.isEmpty || a.length != b.length) return 0;

    double dot = 0, normA = 0, normB = 0;

    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }

    if (normA == 0 || normB == 0) return 0;
    return dot / (sqrt(normA) * sqrt(normB));
  }

  // ===============================
  // CLEANUP
  // ===============================
  void dispose() {
    _interpreter?.close();
  }
}
