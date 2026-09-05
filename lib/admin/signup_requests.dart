import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/email_service.dart';

class SignupRequestsPage extends StatelessWidget {
  const SignupRequestsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),

      appBar: AppBar(
        title: const Text("Signup Requests"),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('signup_requests')
            .where('status', isEqualTo: 'pending')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF0B5CAD)),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(
              child: Text(
                "No pending signup requests",
                style: TextStyle(fontSize: 16, color: Color(0xFF64748B)),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(14),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;

              return Card(
                color: Colors.white,
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFE0F2FE),
                      child: Icon(Icons.person, color: Color(0xFF0B5CAD)),
                    ),
                    title: Text(
                      data['fullName'] ?? 'N/A',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Employee ID: ${data['employeeId']}",
                            style: const TextStyle(color: Color(0xFF64748B)),
                          ),
                          Text(
                            "Email: ${data['email']}",
                            style: const TextStyle(color: Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        /// ✅ APPROVE
                        IconButton(
                          tooltip: "Approve",
                          icon: const Icon(
                            Icons.check_circle,
                            color: Color(0xFF15803D),
                            size: 28,
                          ),
                          onPressed: () =>
                              _confirmApprove(context, doc.id, data),
                        ),

                        /// ❌ REJECT
                        IconButton(
                          tooltip: "Reject",
                          icon: const Icon(
                            Icons.cancel,
                            color: Colors.redAccent,
                            size: 28,
                          ),
                          onPressed: () =>
                              _confirmReject(context, doc.id),
                        ),
                      ],
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

  // ===============================
  // CONFIRM APPROVE (ADD USER + EMAIL)
  // ===============================
  Future<void> _confirmApprove(
    BuildContext context,
    String docId,
    Map<String, dynamic> data,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text(
          "Approve Signup",
          style: TextStyle(color: Color(0xFF0F172A)),
        ),
        content: const Text(
          "Approve this request, add user & notify via email?",
          style: TextStyle(color: Color(0xFF64748B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              "Cancel",
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF15803D),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Approve"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final firestore = FirebaseFirestore.instance;

      /// 0️⃣ ADD USER TO USERS COLLECTION
      await firestore.collection('users').add({
        'fullName': data['fullName'],
        'employeeId': data['employeeId'],
        'email': data['email'],
        'role': 'employee',
        'faceRegistered': false,
        'disabled': false,
        'createdAt': Timestamp.now(),
      });

      /// 1️⃣ UPDATE REQUEST STATUS
      await firestore
          .collection('signup_requests')
          .doc(docId)
          .update({'status': 'approved'});

      /// 2️⃣ SEND EMAIL
      await EmailService.sendApprovalEmail(
        name: data['fullName'],
        email: data['email'],
        employeeId: data['employeeId'],
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Approved, user added & email sent"),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    }
  }

  // ===============================
  // CONFIRM REJECT
  // ===============================
  Future<void> _confirmReject(
    BuildContext context,
    String docId,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text(
          "Reject Signup",
          style: TextStyle(color: Color(0xFF0F172A)),
        ),
        content: const Text(
          "Are you sure you want to reject this request?",
          style: TextStyle(color: Color(0xFF64748B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              "Cancel",
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Reject"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await FirebaseFirestore.instance
        .collection('signup_requests')
        .doc(docId)
        .update({'status': 'rejected'});

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Request rejected"),
        ),
      );
    }
  }
}
