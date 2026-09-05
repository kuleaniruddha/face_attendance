import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserDetail extends StatelessWidget {
  final String userId;

  const UserDetail({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final userRef =
        FirebaseFirestore.instance.collection('users').doc(userId);
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),

      appBar: AppBar(
        title: const Text("User Details"),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
      ),

      body: FutureBuilder<DocumentSnapshot>(
        future: userRef.get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.cyanAccent),
            );
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
              child: Text(
                "User not found",
                style: TextStyle(color: Color(0xFF64748B)),
              ),
            );
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;

          final fullName = data['fullName'] ?? 'N/A';
          final employeeId = data['employeeId'] ?? 'N/A';
          final email = data['email'] ?? 'N/A';
          final faceRegistered = data['faceRegistered'] == true;
          final disabled = data['disabled'] == true;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                /// 👤 PROFILE CARD
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const CircleAvatar(
                        radius: 42,
                        backgroundColor: Colors.blueAccent,
                        child: Icon(
                          Icons.person,
                          size: 44,
                          color: Colors.white,
                        ),
                      ),

                      const SizedBox(height: 14),

                      Text(
                        fullName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),

                      const SizedBox(height: 6),

                      Text(
                        email,
                        style: const TextStyle(color: Color(0xFF64748B)),
                      ),

                      const SizedBox(height: 20),

                      _infoRow("Employee ID", employeeId),

                      const SizedBox(height: 14),

                      _statusChip(
                        "Face Data",
                        faceRegistered ? "Registered" : "Not Registered",
                        faceRegistered
                            ? Colors.greenAccent
                            : Colors.redAccent,
                      ),

                      const SizedBox(height: 10),

                      _statusChip(
                        "Account Status",
                        disabled ? "Disabled" : "Active",
                        disabled
                            ? Colors.redAccent
                            : Colors.greenAccent,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                /// ⚙️ ACTIONS
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Admin Actions",
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                          color: const Color(0xFF0F172A),
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),

                const SizedBox(height: 14),

                _actionButton(
                  context,
                  icon: Icons.face_retouching_off,
                  label: "Delete Face Data",
                  color: Colors.orangeAccent,
                  onPressed: () async {
                    await userRef.update({
                      'faceEmbedding': FieldValue.delete(),
                      'faceEmbeddingModel': FieldValue.delete(),
                      'faceEmbeddingSize': FieldValue.delete(),
                      'faceRegistered': false,
                    });
                    _showSnack(context, "Face data deleted");
                  },
                ),

                _actionButton(
                  context,
                  icon: disabled ? Icons.lock_open : Icons.lock,
                  label:
                      disabled ? "Enable Account" : "Disable Account",
                  color: Colors.blueGrey,
                  onPressed: () async {
                    await userRef.update({'disabled': !disabled});
                    _showSnack(
                      context,
                      disabled
                          ? "Account enabled"
                          : "Account disabled",
                    );
                  },
                ),

                _actionButton(
                  context,
                  icon: Icons.delete_forever,
                  label: "Delete User",
                  color: Colors.redAccent,
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        backgroundColor:
                            Colors.white,
                        title: const Text(
                          "Delete User",
                          style: TextStyle(color: Color(0xFF0F172A)),
                        ),
                        content: const Text(
                          "This will permanently delete the user and all associated data.",
                          style:
                              TextStyle(color: Color(0xFF64748B)),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.pop(context, false),
                            child: const Text(
                              "Cancel",
                              style:
                                  TextStyle(color: Color(0xFF64748B)),
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
                      await userRef.delete();

                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    }
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// INFO ROW
  Widget _infoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
          ),
        ),
        Text(
          value,
          style: const TextStyle(color: Color(0xFF0F172A)),
        ),
      ],
    );
  }

  /// STATUS CHIP
  Widget _statusChip(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
          ),
        ),
        Chip(
          label: Text(
            value,
            style: const TextStyle(color: Colors.black),
          ),
          backgroundColor: color,
        ),
      ],
    );
  }

  /// ACTION BUTTON
  Widget _actionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton.icon(
          icon: Icon(icon),
          label: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: onPressed,
        ),
      ),
    );
  }

  void _showSnack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }
}
