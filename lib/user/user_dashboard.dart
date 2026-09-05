import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'attendance_day_details.dart';
import 'mark_attendance.dart';
import 'register_face.dart';

class UserDashboard extends StatefulWidget {
  const UserDashboard({super.key});

  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late final String uid;
  late final String email;

  bool faceRegistered = false;
  bool attendanceMarkedToday = false;
  bool leaveMarkedToday = false;

  String fullName = "User";
  int monthlyPresentCount = 0;

  late final Stream<QuerySnapshot> attendanceHistoryStream;

  @override
  void initState() {
    super.initState();

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      // User not logged in → redirect safely to login
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed('/login');
      });
      return;
    }

    uid = user.uid;
    email = user.email ?? '';

    attendanceHistoryStream = FirebaseFirestore.instance
        .collection('attendance')
        .where('uid', isEqualTo: uid)
        .orderBy('date', descending: true)
        .snapshots();

    _loadDashboardData();
  }

  /// ================= LOAD DATA =================

  Future<void> _loadDashboardData() async {
    await Future.wait([
      _loadUserProfile(),
      _checkTodayAttendance(),
    ]);

    await _loadMonthlySummary();
    if (mounted) setState(() {});
  }

  Future<void> _loadUserProfile() async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        final nameVal = data['fullName'] ?? data['name'];
        if (nameVal != null && nameVal.toString().trim().isNotEmpty) {
          fullName = nameVal.toString().trim();
        } else if (_auth.currentUser?.displayName != null &&
            _auth.currentUser!.displayName!.isNotEmpty) {
          fullName = _auth.currentUser!.displayName!;
        } else if (email.isNotEmpty) {
          fullName = email.split('@').first;
        }
        faceRegistered = data['faceRegistered'] ?? false;
      } else {
        final user = _auth.currentUser;
        if (user?.displayName != null && user!.displayName!.isNotEmpty) {
          fullName = user.displayName!;
        } else if (email.isNotEmpty) {
          fullName = email.split('@').first;
        }
      }
    } catch (e) {
      debugPrint("Error loading user profile: $e");
    }
  }

  Future<void> _checkTodayAttendance() async {
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      final snapshot = await _firestore
          .collection('attendance')
          .where('uid', isEqualTo: uid)
          .where('date', isEqualTo: today)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        attendanceMarkedToday = true;
        final data = snapshot.docs.first.data();
        leaveMarkedToday = data['outTime'] != null;
      } else {
        attendanceMarkedToday = false;
        leaveMarkedToday = false;
      }
    } catch (e) {
      debugPrint("Error checking today attendance: $e");
    }
  }

  Future<void> _loadMonthlySummary() async {
    try {
      final now = DateTime.now();
      final currentMonthStr = DateFormat('yyyy-MM').format(now);

      final snapshot = await _firestore
          .collection('attendance')
          .where('uid', isEqualTo: uid)
          .get();

      monthlyPresentCount = snapshot.docs.where((doc) {
        final data = doc.data();
        final String? dateStr = data['date'];
        if (dateStr != null && dateStr.startsWith(currentMonthStr)) {
          return true;
        }
        final Timestamp? inTime = data['inTime'] as Timestamp?;
        if (inTime != null) {
          final dt = inTime.toDate();
          return dt.year == now.year && dt.month == now.month;
        }
        return false;
      }).length;
    } catch (e) {
      debugPrint("Error loading monthly summary: $e");
    }
  }

  /// ================= UI =================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text("Dashboard"),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _auth.signOut();
              if (!mounted) return;
              Navigator.of(context).pushReplacementNamed('/login');
            },
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        color: Colors.blueAccent,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// GREETING
              _greetingCard(fullName),

              const SizedBox(height: 20),

              /// STATUS CARDS
              Row(
                children: [
                  Expanded(
                    child: _statusCard(
                      "Today's Status",
                      attendanceMarkedToday ? "Marked" : "Not Marked",
                      attendanceMarkedToday
                          ? Icons.check_circle
                          : Icons.error_outline,
                      attendanceMarkedToday
                          ? Colors.green
                          : Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _statusCard(
                      "Face Data",
                      faceRegistered ? "Registered" : "Not Added",
                      Icons.face,
                      faceRegistered
                          ? Colors.blue
                          : Colors.red,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              /// ACTION BUTTONS
              _primaryButton(
                icon: Icons.camera_alt,
                label: "Mark Attendance",
                enabled: !attendanceMarkedToday,
                color: const Color(0xFF0B5CAD),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const MarkAttendance()),
                  );
                  _loadDashboardData();
                },
              ),

              const SizedBox(height: 12),

              _secondaryButton(
                icon: Icons.face_retouching_natural,
                label: "Register Face",
                enabled: !faceRegistered,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const RegisterFace()),
                  );
                  _loadDashboardData();
                },
              ),

              const SizedBox(height: 12),

              _secondaryButton(
                icon: Icons.lock_reset,
                label: "Change Password",
                enabled: true,
                onTap: _changePassword,
              ),

              const SizedBox(height: 30),

              /// MONTHLY SUMMARY (TABLE)
              const Text(
                "Monthly Summary",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 10),

              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        SummaryHeader("Metric"),
                        SummaryHeader("Count"),
                      ],
                    ),
                    const Divider(color: Color(0xFFE2E8F0)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const SummaryCell("Days Present This Month"),
                        SummaryCell(monthlyPresentCount.toString()),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              /// ATTENDANCE HISTORY
              const Text(
                "Attendance History",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 10),

              _attendanceHistory(),
            ],
          ),
        ),
      ),
    );
  }

  /// ================= SECTIONS =================

  Widget _attendanceHistory() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('attendance')
          .where('uid', isEqualTo: uid)
          .orderBy('date', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              "No attendance records found.",
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          );
        }

        final attendanceDocs = snapshot.data!.docs;

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: attendanceDocs.length,
          itemBuilder: (context, index) {
            final doc = attendanceDocs[index];
            final data = doc.data() as Map<String, dynamic>;

            final String date = data['date'] ?? '';
            final int minutes = data['totalWorkingMinutes'] ?? 0;
            final String hours = (minutes / 60).toStringAsFixed(2);
            final String docId = doc.id;

            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AttendanceDayDetails(
                      docId: docId,
                      date: date,
                    ),
                  ),
                );
              },
              child: FutureBuilder<QuerySnapshot>(
                future: FirebaseFirestore.instance
                    .collection('attendance_logs')
                    .doc(docId)
                    .collection('logs')
                    .orderBy('time')
                    .get(),
                builder: (context, logSnapshot) {
                  List<String> sessions = [];
                  String? lastIn;

                  if (logSnapshot.hasData && logSnapshot.data!.docs.isNotEmpty) {
                    for (var logDoc in logSnapshot.data!.docs) {
                      final logData = logDoc.data() as Map<String, dynamic>;
                      final type = logData['type'];
                      final Timestamp? timeStamp = logData['time'] as Timestamp?;

                      if (timeStamp == null) continue;
                      final formattedTime =
                          DateFormat('hh:mm a').format(timeStamp.toDate());

                      if (type == 'IN') {
                        lastIn = formattedTime;
                      } else if (type == 'OUT' && lastIn != null) {
                        sessions.add("$lastIn - $formattedTime");
                        lastIn = null;
                      }
                    }
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              date,
                              style: const TextStyle(
                                color: Color(0xFF0F172A),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              "$hours h",
                              style: const TextStyle(
                                color: Color(0xFF15803D),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const Divider(color: Color(0xFFE2E8F0)),
                        ...sessions.map(
                          (s) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.schedule,
                                  size: 14,
                                  color: Colors.blueAccent,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  s,
                                  style: const TextStyle(
                                    color: Color(0xFF475569),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (sessions.isEmpty && lastIn != null)
                          const Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: Text(
                              "🟡 Active session (checked in)",
                              style: TextStyle(
                                color: Color(0xFFB45309),
                                fontSize: 13,
                              ),
                            ),
                          ),
                        if (sessions.isEmpty && lastIn == null)
                          const Text(
                            "No completed sessions",
                            style: TextStyle(color: Color(0xFF64748B)),
                          ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  /// ================= WIDGETS =================

  Widget _statusCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(color: Color(0xFF64748B))),
          const SizedBox(height: 6),
          Text(value,
              style:
                  TextStyle(fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _primaryButton({
    required IconData icon,
    required String label,
    required bool enabled,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        icon: Icon(icon),
        label: Text(label),
        onPressed: enabled ? onTap : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Widget _secondaryButton({
    required IconData icon,
    required String label,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        icon: Icon(icon),
        label: Text(label),
        onPressed: enabled ? onTap : null,
      ),
    );
  }

  Future<void> _changePassword() async {
    if (email.isEmpty) return;
    await _auth.sendPasswordResetEmail(email: email);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text("Password reset link sent to your email")),
    );
  }
}

/// ================= EXTRA WIDGETS =================

class SummaryHeader extends StatelessWidget {
  final String text;
  const SummaryHeader(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 13,
            fontWeight: FontWeight.bold));
  }
}

class SummaryCell extends StatelessWidget {
  final String text;
  const SummaryCell(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 14,
            fontWeight: FontWeight.w600));
  }
}

Widget _greetingCard(String name) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xFFE2E8F0)),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        const CircleAvatar(
          radius: 28,
          backgroundColor: Color(0xFFE0F2FE),
          child: Icon(Icons.person, size: 30, color: Color(0xFF0B5CAD)),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Welcome 👋",
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              name.isEmpty ? "User" : name,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
