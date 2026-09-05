import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class UserAttendanceDetail extends StatelessWidget {
  final String userId;

  const UserAttendanceDetail({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),

      appBar: AppBar(
        title: const Text("User Attendance"),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        centerTitle: true,
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('attendance')
            .where('uid', isEqualTo: userId)
            .orderBy('date', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.cyanAccent),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(
              child: Text(
                "No attendance records found",
                style: TextStyle(color: Color(0xFF64748B)),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;

              /// STATUS (SAFE)
              final String status =
                  (data['status'] ?? 'absent').toString().toLowerCase();
              final bool isPresent = status != 'absent';

              /// DATE (SAFE)
              final String date = data['date'] ?? '--';

              final Timestamp? inTime = data['inTime'] as Timestamp?;
              final Timestamp? outTime = data['outTime'] as Timestamp?;
              final inTimeText = inTime != null
                  ? DateFormat('HH:mm').format(inTime.toDate())
                  : '--';
              final outTimeText = outTime != null
                  ? DateFormat('HH:mm').format(outTime.toDate())
                  : '--';

              String workingHoursText = "Working Hours: --";

              /// WORKING HOURS CALCULATION
              if (inTime != null && outTime != null) {
                final duration = outTime.toDate().difference(inTime.toDate());
                final hours = duration.inHours;
                final minutes = duration.inMinutes % 60;
                workingHoursText = "Working Hours: ${hours}h ${minutes}m";
              }

              return Card(
                color: Colors.white,
                elevation: 4,
                margin:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: ListTile(
                    leading: Icon(
                      isPresent
                          ? Icons.check_circle
                          : Icons.cancel,
                      color: isPresent
                          ? Colors.greenAccent
                          : Colors.redAccent,
                      size: 28,
                    ),
                    title: Text(
                      date,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        "IN: $inTimeText\n"
                        "OUT: $outTimeText\n"
                        "$workingHoursText\n"
                        "Status: ${isPresent ? 'Present' : 'Absent'}",
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          height: 1.4,
                        ),
                      ),
                    ),
                    isThreeLine: true,

                    /// DELETE
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.delete,
                        color: Colors.redAccent,
                      ),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            backgroundColor:
                                Colors.white,
                            title: const Text(
                              "Delete Attendance",
                              style:
                                  TextStyle(color: Color(0xFF0F172A)),
                            ),
                            content: const Text(
                              "Are you sure you want to delete this record?",
                              style: TextStyle(
                                  color: Color(0xFF64748B)),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(context, false),
                                child: const Text(
                                  "Cancel",
                                  style: TextStyle(
                                      color: Color(0xFF64748B)),
                                ),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      Colors.redAccent,
                                ),
                                onPressed: () =>
                                    Navigator.pop(context, true),
                                child: const Text("Delete"),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true) {
                          await FirebaseFirestore.instance
                              .collection('attendance')
                              .doc(doc.id)
                              .delete();
                        }
                      },
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
