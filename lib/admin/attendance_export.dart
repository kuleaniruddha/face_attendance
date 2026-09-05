import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

class AttendanceExport extends StatefulWidget {
  const AttendanceExport({super.key});

  @override
  State<AttendanceExport> createState() => _AttendanceExportState();
}

class _AttendanceExportState extends State<AttendanceExport> {
  bool _isExporting = false;
  DateTime? _selectedDate;

  // ==========================
  // PICK DATE
  // ==========================
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      initialDate: _selectedDate ?? DateTime.now(),
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  // ==========================
  // EXPORT ATTENDANCE
  // ==========================
  Future<void> _exportAttendance() async {
    if (_selectedDate == null) {
      _showSnack("Please select a date");
      return;
    }

    setState(() => _isExporting = true);

    try {
      final permission = await Permission.storage.request();
      if (!permission.isGranted) {
        _showSnack("Storage permission denied");
        return;
      }

      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate!);

      final snapshot = await FirebaseFirestore.instance
          .collection('attendance')
          .where('date', isEqualTo: dateStr)
          .get();

      if (snapshot.docs.isEmpty) {
        _showSnack("No attendance found for $dateStr");
        return;
      }

      /// CSV HEADER
      final List<List<dynamic>> csvData = [
        [
          "UID",
          "Date",
          "In Time",
          "Out Time",
          "Working Hours",
          "Status",
        ]
      ];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final Timestamp? inTime = data['inTime'] as Timestamp?;
        final Timestamp? outTime = data['outTime'] as Timestamp?;

        csvData.add([
          data['uid'] ?? '',
          data['date'] ?? '',
          inTime != null ? DateFormat('HH:mm').format(inTime.toDate()) : '',
          outTime != null ? DateFormat('HH:mm').format(outTime.toDate()) : '',
          data['workingHours']?.toString() ?? '',
          data['status'] ?? '',
        ]);
      }

      final csv = const ListToCsvConverter().convert(csvData);

      final directory = Directory('/storage/emulated/0/Download');
      if (!directory.existsSync()) {
        directory.createSync(recursive: true);
      }

      final fileName = "attendance_$dateStr.csv";
      final file = File("${directory.path}/$fileName");
      await file.writeAsString(csv);

      _showSnack("CSV exported successfully 📂\n$fileName");
    } catch (e) {
      _showSnack("Export failed: $e");
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  // ==========================
  // UI
  // ==========================
  @override
  Widget build(BuildContext context) {
    final dateText = _selectedDate == null
        ? "Select Date"
        : DateFormat('dd MMM yyyy').format(_selectedDate!);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),

      appBar: AppBar(
        title: const Text("Export Attendance"),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
      ),

      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Export Attendance (Day Wise)",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),

            const SizedBox(height: 16),

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: const Icon(Icons.calendar_today, color: Colors.cyan),
                title: Text(
                  dateText,
                  style: const TextStyle(color: Color(0xFF0F172A)),
                ),
                trailing: const Icon(Icons.edit, color: Color(0xFF64748B)),
                onTap: _pickDate,
              ),
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.download),
                label: Text(
                  _isExporting ? "Exporting..." : "Export CSV",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: _isExporting ? null : _exportAttendance,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0B5CAD),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
