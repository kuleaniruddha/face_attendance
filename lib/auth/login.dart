import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../user/user_dashboard.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _auth = AuthService();
  final _email = TextEditingController();
  final _password = TextEditingController();

  final LocalAuthentication _localAuth = LocalAuthentication();

  bool rememberMe = false;
  bool isBiometricAvailable = false;

  @override
  void initState() {
    super.initState();
    _loadSavedEmail();
    _checkBiometric();
  }

  /// ================= LOAD SAVED EMAIL =================
  Future<void> _loadSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();

    final savedRemember = prefs.getBool('rememberMe') ?? false;
    final savedEmail = prefs.getString('email');

    setState(() {
      rememberMe = savedRemember;
      if (savedRemember && savedEmail != null) {
        _email.text = savedEmail;
      }
    });
  }

  /// ================= CHECK BIOMETRIC =================
  Future<void> _checkBiometric() async {
    final canCheck = await _localAuth.canCheckBiometrics;
    final isSupported = await _localAuth.isDeviceSupported();

    setState(() {
      isBiometricAvailable = canCheck && isSupported;
    });
  }

  /// ================= NORMAL LOGIN =================
  Future<void> login() async {
    if (_email.text.isEmpty || _password.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Email and Password required")),
      );
      return;
    }

    try {
      final user = await _auth.login(
        _email.text,
        _password.text,
      );

      if (user != null && mounted) {
        final prefs = await SharedPreferences.getInstance();

        if (rememberMe) {
          await prefs.setBool('rememberMe', true);
          await prefs.setString('email', _email.text);
        } else {
          await prefs.clear();
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const UserDashboard()),
        );
      }
    } on FirebaseAuthException catch (e) {
      String msg = "Login failed";

      if (e.code == 'user-not-found') {
        msg = "No account found with this email";
      } else if (e.code == 'wrong-password') {
        msg = "Incorrect password";
      } else if (e.code == 'invalid-email') {
        msg = "Invalid email format";
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  /// ================= BIOMETRIC LOGIN (FIXED) =================
  Future<void> biometricLogin() async {
  try {
    final prefs = await SharedPreferences.getInstance();

    final savedRemember = prefs.getBool('rememberMe') ?? false;
    final savedEmail = prefs.getString('email');

    // ❌ Biometric allowed only if Remember Me was enabled
    if (!savedRemember || savedEmail == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please login once using Email & Password"),
        ),
      );
      return;
    }

    // 🔥 BLOCK if user edited email manually
    if (_email.text.trim() != savedEmail) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Email changed. Login with password first."),
        ),
      );
      return;
    }

    final bool canCheck = await _localAuth.canCheckBiometrics;
    final bool isSupported = await _localAuth.isDeviceSupported();

    if (!canCheck || !isSupported) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Biometric not available")),
      );
      return;
    }

    final bool authenticated = await _localAuth.authenticate(
      localizedReason: 'Unlock $savedEmail',
      options: const AuthenticationOptions(
        biometricOnly: true,
        stickyAuth: true,
      ),
    );

    if (!authenticated || !mounted) return;

    // 🔐 FINAL SESSION VALIDATION
    final user = FirebaseAuth.instance.currentUser;

    if (user == null || user.email != savedEmail) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Session expired. Login again."),
        ),
      );
      return;
    }

    // ✅ SUCCESS
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const UserDashboard()),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Biometric failed: $e")),
    );
  }
}

  /// ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text("User Login"),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Container(
            padding: const EdgeInsets.all(24),
            constraints: const BoxConstraints(maxWidth: 420),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A0F172A),
                  blurRadius: 14,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                const CircleAvatar(
                  radius: 36,
                  backgroundColor: Color(0xFFE0F2FE),
                  child: Icon(Icons.person, size: 42, color: Color(0xFF0B5CAD)),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Welcome Back",
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 6),
                const Text(
                  "Login to mark your attendance",
                  style: TextStyle(color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 30),

                /// EMAIL
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    labelText: "Email",
                    labelStyle: const TextStyle(color: Color(0xFF64748B)),
                    prefixIcon:
                        const Icon(Icons.email, color: Color(0xFF0B5CAD)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),

                /// PASSWORD
                TextField(
                  controller: _password,
                  obscureText: true,
                  style: const TextStyle(color: Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    labelText: "Password",
                    labelStyle: const TextStyle(color: Color(0xFF64748B)),
                    prefixIcon:
                        const Icon(Icons.lock, color: Color(0xFF0B5CAD)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 10),

                /// REMEMBER ME
                Row(
                  children: [
                    Checkbox(
                      value: rememberMe,
                      activeColor: const Color(0xFF0B5CAD),
                      onChanged: (value) {
                        setState(() => rememberMe = value!);
                      },
                    ),
                    const Text("Remember me",
                        style: TextStyle(color: Color(0xFF475569))),
                  ],
                ),
                const SizedBox(height: 20),

                /// LOGIN BUTTON
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0B5CAD),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text(
                      "LOGIN",
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

                /// BIOMETRIC BUTTON
                if (isBiometricAvailable) ...[
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: biometricLogin,
                    icon: const Icon(Icons.fingerprint,
                        color: Color(0xFF0B5CAD)),
                    label: const Text(
                      "Login with Face ID / Fingerprint",
                      style: TextStyle(color: Color(0xFF0B5CAD)),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF0B5CAD)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
