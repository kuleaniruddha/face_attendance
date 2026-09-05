import 'package:flutter/material.dart';
import '../services/auth_service.dart';

import 'manage_users.dart';
import 'attendance_export.dart';
import 'attendance_records.dart';
import 'signup_requests.dart';
import 'widgets/admin_card.dart';
import 'update_location.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),

      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "Admin Dashboard",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F172A),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              tooltip: "Logout",
              splashRadius: 22,
              icon: const Icon(Icons.logout, color: Color(0xFF0F172A)),
              onPressed: () async {
                await auth.logout();
                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
            ),
          ),
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// 🔹 HEADER CARD
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: const [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: Color(0xFFFFE4E6),
                    child: Icon(
                      Icons.admin_panel_settings,
                      color: Color(0xFFE11D48),
                      size: 30,
                    ),
                  ),
                  SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Welcome, Admin",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "Manage users & attendance system",
                        style: TextStyle(color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            /// 🔹 SECTION TITLE
            const Text(
              "Admin Controls",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),

            const SizedBox(height: 16),

            /// 🔹 SIGNUP REQUESTS
            AdminCard(
              icon: Icons.pending_actions,
              title: "Signup Requests",
              subtitle: "Approve or reject user access requests",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SignupRequestsPage(),
                  ),
                );
              },
            ),

            /// 🔹 MANAGE USERS
            AdminCard(
              icon: Icons.people,
              title: "Manage Users",
              subtitle: "View, enable or delete employees",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ManageUsers(),
                  ),
                );
              },
            ),

            /// 🔹 UPDATE OFFICE LOCATION
            AdminCard(
              icon: Icons.location_on,
              title: "Office Location",
              subtitle: "Change office geo-fence settings",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const UpdateOfficeLocation(),
                  ),
                );
              },
            ),


            /// 🔹 ATTENDANCE RECORDS
            AdminCard(
              icon: Icons.receipt_long,
              title: "Attendance Records",
              subtitle: "View daily attendance logs",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AttendanceRecords(),
                  ),
                );
              },
            ),

            /// 🔹 EXPORT ATTENDANCE
            AdminCard(
              icon: Icons.download,
              title: "Export Attendance",
              subtitle: "Download attendance as CSV / Excel",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AttendanceExport(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
