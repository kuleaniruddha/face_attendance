import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SignInRequestPage extends StatefulWidget {
  const SignInRequestPage({super.key});

  @override
  State<SignInRequestPage> createState() => _SignInRequestPageState();
}

class _SignInRequestPageState extends State<SignInRequestPage> {
  final _nameCtrl = TextEditingController();
  final _empCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  bool _loading = false;

  Future<void> _submitRequest() async {
    if (_nameCtrl.text.isEmpty ||
        _empCtrl.text.isEmpty ||
        _emailCtrl.text.isEmpty) return;

    setState(() => _loading = true);

    await FirebaseFirestore.instance.collection('signup_requests').add({
      'fullName': _nameCtrl.text.trim(),
      'employeeId': _empCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'status': 'pending',
      'createdAt': Timestamp.now(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Request submitted. Await admin approval."),
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text("Request Access"),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 450),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.10),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                /// ICON
                const CircleAvatar(
                  radius: 36,
                  backgroundColor: Color(0xFFE0F2FE),
                  child: Icon(
                    Icons.assignment_ind,
                    size: 40,
                    color: Color(0xFF0B5CAD),
                  ),
                ),

                const SizedBox(height: 16),

                const Text(
                  "Access Request",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),

                const SizedBox(height: 6),

                const Text(
                  "Submit your details for admin approval",
                  style: TextStyle(color: Color(0xFF64748B)),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 30),

                /// FULL NAME
                TextField(
                  controller: _nameCtrl,
                  style: const TextStyle(color: Color(0xFF0F172A)),
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: "Full Name",
                    labelStyle: const TextStyle(color: Color(0xFF64748B)),
                    prefixIcon:
                        const Icon(Icons.person, color: Color(0xFF64748B)),
                    enabledBorder: OutlineInputBorder(
                      borderSide:
                          const BorderSide(color: Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide:
                          const BorderSide(color: Colors.blue),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                /// EMPLOYEE ID
                TextField(
                  controller: _empCtrl,
                  style: const TextStyle(color: Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    labelText: "Employee ID",
                    labelStyle: const TextStyle(color: Color(0xFF64748B)),
                    prefixIcon:
                        const Icon(Icons.badge, color: Color(0xFF64748B)),
                    enabledBorder: OutlineInputBorder(
                      borderSide:
                          const BorderSide(color: Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide:
                          const BorderSide(color: Colors.blue),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                /// EMAIL
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    labelText: "Official Email",
                    labelStyle: const TextStyle(color: Color(0xFF64748B)),
                    prefixIcon:
                        const Icon(Icons.email, color: Color(0xFF64748B)),
                    enabledBorder: OutlineInputBorder(
                      borderSide:
                          const BorderSide(color: Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide:
                          const BorderSide(color: Colors.blue),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                /// SUBMIT BUTTON
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _submitRequest,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            "Submit Request",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
