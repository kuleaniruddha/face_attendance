import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Check if attendance has been marked today
  Future<bool> isAttendanceMarkedToday() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final today = DateTime.now().toIso8601String().substring(0, 10);
    final docId = "${user.uid}_$today";

    final doc = await _firestore
        .collection('attendance')
        .doc(docId)
        .get();

    return doc.exists && doc.data()?['inTime'] != null;
  }

  /// Mark the FIRST IN time when face is verified
  Future<void> markFirstIn() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("No user logged in");

    final today = DateTime.now().toIso8601String().substring(0, 10);
    final docId = "${user.uid}_$today";

    // Check if already marked
    final existing = await _firestore
        .collection('attendance')
        .doc(docId)
        .get();

    if (existing.exists && existing.data()?['inTime'] != null) {
      throw Exception("Attendance already marked today");
    }

    // Get current location from LocationService (you'll need to pass this)
    // For now, we'll mark without location - update when face scan happens
    await _firestore
        .collection('attendance')
        .doc(docId)
        .set({
      'uid': user.uid,
      'date': today,
      'inTime': FieldValue.serverTimestamp(),
      'inTimestamp': FieldValue.serverTimestamp(),
      'inLat': null,  // Will be updated by location service
      'inLng': null,
      'outTime': null,
      'outLat': null,
      'outLng': null,
      'status': 'active',
      'verificationMethod': 'facenet_embedding',
    }, SetOptions(merge: true));
  }

  /// Update IN location after face verification
  Future<void> updateInLocation(double lat, double lng) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final today = DateTime.now().toIso8601String().substring(0, 10);
    final docId = "${user.uid}_$today";

    await _firestore
        .collection('attendance')
        .doc(docId)
        .update({
      'inLat': lat,
      'inLng': lng,
    });
  }

  /// Get stored face embedding
  Future<List<double>?> getStoredEmbedding(String uid) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(uid)
          .get();

      if (!doc.exists) return null;

      final data = doc.data();
      if (data == null || !data.containsKey('faceEmbedding')) {
        return null;
      }

      final embedding = data['faceEmbedding'];
      if (embedding is List) {
        return embedding.map((e) => (e as num).toDouble()).toList();
      }

      return null;
    } catch (e) {
      print("Error fetching embedding: $e");
      return null;
    }
  }

  /// Get today's attendance record
  Future<Map<String, dynamic>?> getTodayAttendance() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final today = DateTime.now().toIso8601String().substring(0, 10);
    final docId = "${user.uid}_$today";

    final doc = await _firestore
        .collection('attendance')
        .doc(docId)
        .get();

    if (!doc.exists) return null;
    return doc.data();
  }

  /// Get all movements for today (audit trail)
  Future<List<Map<String, dynamic>>> getTodayMovements() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    final today = DateTime.now().toIso8601String().substring(0, 10);
    final docId = "${user.uid}_$today";

    final snapshot = await _firestore
        .collection('attendance_logs')
        .doc(docId)
        .collection('logs')
        .orderBy('time', descending: false)
        .get();

    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  /// Get attendance history for a user
  Future<List<Map<String, dynamic>>> getAttendanceHistory(
    String uid, {
    int limit = 30,
  }) async {
    final snapshot = await _firestore
        .collection('attendance')
        .where('uid', isEqualTo: uid)
        .orderBy('date', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  /// Calculate total hours worked today
  Future<double> getTodayWorkingHours() async {
    final attendance = await getTodayAttendance();
    if (attendance == null) return 0.0;

    final inTime = attendance['inTime'] as Timestamp?;
    final outTime = attendance['outTime'] as Timestamp?;

    if (inTime == null) return 0.0;

    final inDateTime = inTime.toDate();
    final outDateTime = outTime?.toDate() ?? DateTime.now();

    final duration = outDateTime.difference(inDateTime);
    return duration.inMinutes / 60.0;
  }
}
