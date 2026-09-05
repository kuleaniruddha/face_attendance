import 'dart:async';
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

    _startFlow();
  }

  Future<void> _startFlow() async {
    /// STAGE 1 — TEXT
    _textController.forward();
    await Future.delayed(const Duration(milliseconds: 1600));

    /// STAGE 2 — LOGO
    setState(() => showFinalLogo = true);

    /// 🔴 LOCATION SERVICE ENABLED?
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      return;
    }

    /// 🔴 PERMISSION CHECK
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    /// 🔴 BACKGROUND PERMISSION REQUIRED
    if (permission != LocationPermission.always) {
      _showPermissionDialog();
      return;
    }

    /// ✅ START BACKGROUND LOCATION SERVICE
    await LocationService.init();

    await Future.delayed(const Duration(milliseconds: 1200));

    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/welcome');
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("Permission Required"),
        content: const Text(
          "Please allow Location → Allow all the time to enable attendance tracking.",
        ),
        actions: [
          TextButton(
            onPressed: () => Geolocator.openAppSettings(),
            child: const Text("OPEN SETTINGS"),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: showFinalLogo ? _finalLogo() : _animatedText(),
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
            letterSpacing: 0.7,
          ),
        ),
      ],
    );
  }
}
