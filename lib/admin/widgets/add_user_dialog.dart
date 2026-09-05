import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddUserDialog extends StatefulWidget {
  const AddUserDialog({super.key});

  @override
  State<AddUserDialog> createState() => _AddUserDialogState();
}

class _AddUserDialogState extends State<AddUserDialog> {
  final _nameCtrl = TextEditingController();
  final _empIdCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  bool _loading = false;

  static const String defaultPassword = "123456";

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Add New Employee"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: "Full Name"),
          ),
          TextField(
            controller: _empIdCtrl,
            decoration: const InputDecoration(labelText: "Employee ID"),
          ),
          TextField(
            controller: _emailCtrl,
            decoration: const InputDecoration(labelText: "Email"),
            keyboardType: TextInputType.emailAddress,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _addUser,
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text("Create User"),
        ),
      ],
    );
  }

  Future<void> _addUser() async {
    if (_nameCtrl.text.isEmpty ||
        _empIdCtrl.text.isEmpty ||
        _emailCtrl.text.isEmpty) {
      _showSnack("All fields are required");
      return;
    }

    setState(() => _loading = true);

    final auth = FirebaseAuth.instance;
    final firestore = FirebaseFirestore.instance;

    UserCredential? userCredential;

    try {
      /// 1️⃣ CREATE AUTH USER
      userCredential = await auth.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: defaultPassword,
      );

      final uid = userCredential.user!.uid;

      /// 2️⃣ SAVE USER PROFILE
      await firestore.collection('users').doc(uid).set({
        'fullName': _nameCtrl.text.trim(),
        'employeeId': _empIdCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'faceRegistered': false,
        'disabled': false,
        'createdAt': Timestamp.now(),
      });

      _showSnack("User created (default password: 1234)");

      if (context.mounted) Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      _showSnack(e.message ?? "Failed to create user");
    } finally {
      setState(() => _loading = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }
}
