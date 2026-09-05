import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AttendanceDayDetails extends StatelessWidget {
  final String docId;
  final String date;

  const AttendanceDayDetails({
    super.key,
    required this.docId,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: Text(date),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('attendance_logs')
            .doc(docId)
            .collection('logs')
            .orderBy('time')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "No logs found",
                style: TextStyle(color: Color(0xFF64748B)),
              ),
            );
          }

          final logs = snapshot.data!.docs;

          DateTime? lastIn;
          final List<Widget> tiles = [];

          for (final log in logs) {
            final data = log.data() as Map<String, dynamic>;

            if (!data.containsKey('time') || !data.containsKey('type')) {
              continue;
            }

            final Timestamp ts = data['time'];
            final DateTime time = ts.toDate();
            final String type = data['type'];

            if (type == 'IN') {
              lastIn = time;
              tiles.add(_tile("IN", time, const Color(0xFF15803D)));
            } else if (type == 'OUT') {
              tiles.add(_tile("OUT", time, const Color(0xFFE11D48)));
              lastIn = null;
            }
          }

          if (lastIn != null) {
            tiles.add(
              Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  "🟡 Currently inside (no OUT yet)",
                  style: TextStyle(
                    color: Color(0xFFB45309),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(8),
            children: tiles,
          );
        },
      ),
    );
  }

  Widget _tile(String label, DateTime time, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ListTile(
        leading: Icon(Icons.schedule, color: color),
        title: Text(
        label,
        style: const TextStyle(color: Color(0xFF0F172A)),
      ),
      trailing: Text(
        DateFormat('HH:mm').format(time),
        style: const TextStyle(
          color: Color(0xFF0F172A),
          fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
