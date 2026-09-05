import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'user_detail.dart';
import 'widgets/add_user_dialog.dart';

class ManageUsers extends StatelessWidget {
  const ManageUsers({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),

      appBar: AppBar(
        title: const Text("Manage Users"),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
      ),

      /// ➕ ADD USER
      floatingActionButton: FloatingActionButton(
        tooltip: "Add Employee",
        backgroundColor: const Color(0xFF0B5CAD),
        foregroundColor: Colors.white,
        onPressed: () {
          showDialog(
            context: context,
            builder: (_) => const AddUserDialog(),
          );
        },
        child: const Icon(Icons.person_add),
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .orderBy('fullName')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF0B5CAD)),
            );
          }

          if (snapshot.hasError) {
            return const Center(
              child: Text(
                "Failed to load users",
                style: TextStyle(color: Color(0xFF64748B)),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(
              child: Text(
                "No users found",
                style: TextStyle(fontSize: 16, color: Color(0xFF64748B)),
              ),
            );
          }

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 4),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;

              final name =
                  data['fullName']?.toString().trim().isNotEmpty == true
                      ? data['fullName']
                      : 'Unnamed User';

              final employeeId =
                  data['employeeId']?.toString().trim().isNotEmpty == true
                      ? data['employeeId']
                      : 'N/A';

              return Card(
                color: Colors.white,
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE0F2FE),
                    child: Icon(Icons.person, color: Color(0xFF0B5CAD)),
                  ),
                  title: Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  subtitle: Text(
                    "Employee ID: $employeeId",
                    style: const TextStyle(color: Color(0xFF64748B)),
                  ),

                  /// ➡ USER DETAIL
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UserDetail(userId: doc.id),
                      ),
                    );
                  },

                  /// ❌ DELETE USER
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          backgroundColor: Colors.white,
                          title: const Text(
                            "Delete User",
                            style: TextStyle(color: Color(0xFF0F172A)),
                          ),
                          content: const Text(
                            "This will permanently delete the user and related data.\n\nAre you sure?",
                            style: TextStyle(color: Color(0xFF64748B)),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.pop(context, false),
                              child: const Text(
                                "Cancel",
                                style: TextStyle(color: Color(0xFF64748B)),
                              ),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
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
                            .collection('users')
                            .doc(doc.id)
                            .delete();

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("User deleted successfully"),
                            ),
                          );
                        }
                      }
                    },
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
