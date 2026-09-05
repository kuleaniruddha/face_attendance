import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/location_service.dart';
import 'app_config.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _textController;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  bool showFinalLogo = false;
  bool _navigated = false;
  Timer? _fallbackTimer;

  @override
  void initState() {
    super.initState();

    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fade = CurvedAnimation(
      parent: _textController,
      curve: Curves.easeInOut,
    );

    _slide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _textController,
        curve: Curves.easeOut,
      ),
    );

    // Hard fallback: Navigate after 3.5 seconds no matter what happens
    _fallbackTimer = Timer(const Duration(milliseconds: 3500), () {
      _navigateToWelcome();
    });

    _startFlow();
  }

  void _navigateToWelcome() {
    if (_navigated || !mounted) return;
    _navigated = true;
    _fallbackTimer?.cancel();
    Navigator.pushReplacementNamed(context, '/welcome');
  }

  Future<void> _startFlow() async {
    try {
      /// STAGE 1 — ANIMATED TEXT
      _textController.forward();
      await Future.delayed(const Duration(milliseconds: 1400));

      if (!mounted) return;

      /// STAGE 2 — LOGO & BRANDING
      setState(() => showFinalLogo = true);

      // Attempt location & permission initialization gracefully with a 1.5s timeout
      await _checkAndInitLocation().timeout(
        const Duration(milliseconds: 1500),
        onTimeout: () {
          debugPrint("Location initialization timed out on splash, continuing to welcome screen");
        },
      );
    } catch (e) {
      debugPrint("Splash flow error (non-fatal): $e");
    } finally {
      // Small pause for smooth visual transition
      await Future.delayed(const Duration(milliseconds: 600));
      _navigateToWelcome();
    }
  }

  Future<void> _checkAndInitLocation() async {
    // Only perform background check on mobile platforms
    if (kIsWeb) return;

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        await LocationService.init();
      }
    } catch (e) {
      debugPrint("Location check ignored on splash: $e");
    }
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _navigateToWelcome, // Tap anywhere to skip splash
        child: Center(
          child: showFinalLogo ? _finalLogo() : _animatedText(),
        ),
      ),
    );
  }

  /// TEXT (ANIMATED)
  Widget _animatedText() {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text(
              "SCAN & SMILE",
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.6,
                color: Color(0xFF0F172A),
              ),
            ),
            SizedBox(height: 10),
            Text(
              AppConfig.instituteName,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _finalLogo() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          AppConfig.logoAsset,
          height: 120,
        ),
        const SizedBox(height: 18),
        const Text(
          AppConfig.instituteName,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF475569),
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.7,
          ),
        ),
        const SizedBox(height: 20),
        const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFF0B5CAD),
          ),
        ),
      ],
    );
  }
}
