import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'auth/login.dart';
import 'admin/admin_login.dart';
import 'auth/signin_request.dart';
import 'ml/facenet_service.dart';
import 'splash_screen.dart';
import 'app_config.dart';

///  GLOBAL SINGLETON
late FaceNetService faceNetService;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  faceNetService = FaceNetService();
  await faceNetService.init();

  debugPrint("App started with FaceNet loaded");

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appTitle,
      debugShowCheckedModeBanner: false,

      themeMode: ThemeMode.light,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF7F9FC),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0B5CAD),
          brightness: Brightness.light,
        ),

        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF0F172A),
          elevation: 0,
          surfaceTintColor: Colors.white,
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0B5CAD),
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.6,
            ),
          ),
        ),

        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF0B5CAD),
            side: const BorderSide(color: Color(0xFF0B5CAD)),
            minimumSize: const Size.fromHeight(54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),

      home: const SplashScreen(),
      routes: {
        '/welcome': (context) => const WelcomePage(),
        '/login': (context) => const LoginPage(),
      },
    );
  }
}

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  int _logoTapCount = 0;
  bool _showAdminButton = false;

  void _handleLogoTap() {
    if (_showAdminButton) return;

    setState(() {
      _logoTapCount += 1;
      _showAdminButton = _logoTapCount >= 5;
    });

    if (_showAdminButton) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Admin access enabled")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      body: Container(
        color: const Color(0xFFF7F9FC),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: _handleLogoTap,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x1A0F172A),
                            blurRadius: 18,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(24),
                      child: Image.asset(
                        AppConfig.logoAsset,
                        height: 110,
                      ),
                    ),
                  ),

                  const SizedBox(height: 36),

                  const Text(
                    "FACE ATTENDANCE",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4,
                      color: Color(0xFF0F172A),
                    ),
                  ),

                  const SizedBox(height: 6),

                  const Text(
                    "${AppConfig.instituteName} | FaceNet Powered",
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.6,
                    ),
                  ),

                  const SizedBox(height: 52),

                  ElevatedButton.icon(
                    icon: const Icon(Icons.person),
                    label: const Text("USER LOGIN"),
                    onPressed: () => Navigator.pushNamed(context, '/login'),
                  ),

                  if (_showAdminButton) ...[
                    const SizedBox(height: 18),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.admin_panel_settings),
                      label: const Text("ADMIN LOGIN"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE11D48),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AdminLoginPage(),
                          ),
                        );
                      },
                    ),
                  ],

                  const SizedBox(height: 18),

                  OutlinedButton.icon(
                    icon: const Icon(Icons.app_registration),
                    label: const Text("REQUEST ACCESS"),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SignInRequestPage(),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 50),

                  const Text(
                    "Developed by AK • ANIRUDDHA KULE",
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF94A3B8),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
