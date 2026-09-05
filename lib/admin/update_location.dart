import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../app_config.dart';
import '../services/location_service.dart';

class UpdateOfficeLocation extends StatefulWidget {
  const UpdateOfficeLocation({super.key});

  @override
  State<UpdateOfficeLocation> createState() => _UpdateOfficeLocationState();
}

class _UpdateOfficeLocationState extends State<UpdateOfficeLocation> {
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();
  final _radiusCtrl = TextEditingController();

  bool _loading = false;
  bool _fetchingGps = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
  }

  Future<void> _loadCurrentSettings() async {
    setState(() => _loading = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('attendance')
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final lat = data['officeLat'] ?? data['lat'] ?? AppConfig.officeLatitude;
        final lng = data['officeLng'] ?? data['lng'] ?? AppConfig.officeLongitude;
        final radius = data['allowedRadius'] ?? data['radius'] ?? AppConfig.officeRadiusMeters;

        _latCtrl.text = lat.toString();
        _lngCtrl.text = lng.toString();
        _radiusCtrl.text = radius.toString();
        return;
      }

      // Check fallback collection
      final locSnapshot = await FirebaseFirestore.instance
          .collection('office_locations')
          .limit(1)
          .get();

      if (locSnapshot.docs.isNotEmpty) {
        final data = locSnapshot.docs.first.data();
        final lat = data['lat'] ?? data['officeLat'] ?? AppConfig.officeLatitude;
        final lng = data['lng'] ?? data['officeLng'] ?? AppConfig.officeLongitude;
        final radius = data['radius'] ?? data['allowedRadius'] ?? AppConfig.officeRadiusMeters;

        _latCtrl.text = lat.toString();
        _lngCtrl.text = lng.toString();
        _radiusCtrl.text = radius.toString();
        return;
      }

      _latCtrl.text = AppConfig.officeLatitude.toString();
      _lngCtrl.text = AppConfig.officeLongitude.toString();
      _radiusCtrl.text = AppConfig.officeRadiusMeters.toString();
    } catch (e) {
      _latCtrl.text = AppConfig.officeLatitude.toString();
      _lngCtrl.text = AppConfig.officeLongitude.toString();
      _radiusCtrl.text = AppConfig.officeRadiusMeters.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fetchCurrentGpsLocation() async {
    setState(() => _fetchingGps = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await Geolocator.openLocationSettings();
        throw "Location services are disabled on device";
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw "Location permission denied";
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      _latCtrl.text = position.latitude.toStringAsFixed(6);
      _lngCtrl.text = position.longitude.toStringAsFixed(6);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("📍 Current GPS coordinates loaded!")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _fetchingGps = false);
    }
  }

  void _applyPreset(String name, double lat, double lng, double radius) {
    setState(() {
      _latCtrl.text = lat.toString();
      _lngCtrl.text = lng.toString();
      _radiusCtrl.text = radius.toStringAsFixed(0);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Applied preset: $name")),
    );
  }

  Future<void> _save() async {
    final latText = _latCtrl.text.trim();
    final lngText = _lngCtrl.text.trim();
    final radiusText = _radiusCtrl.text.trim();

    final lat = double.tryParse(latText);
    final lng = double.tryParse(lngText);
    final radius = double.tryParse(radiusText);

    if (lat == null || lat < -90 || lat > 90) {
      _showError("Please enter a valid Latitude (-90 to 90)");
      return;
    }

    if (lng == null || lng < -180 || lng > 180) {
      _showError("Please enter a valid Longitude (-180 to 180)");
      return;
    }

    if (radius == null || radius <= 0) {
      _showError("Please enter a valid Allowed Radius (> 0 meters)");
      return;
    }

    setState(() => _loading = true);

    try {
      final firestore = FirebaseFirestore.instance;

      // 1️⃣ Save to primary settings/attendance
      await firestore.collection('settings').doc('attendance').set({
        'officeLat': lat,
        'officeLng': lng,
        'allowedRadius': radius,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 2️⃣ Synchronize office_locations collection so both settings match
      final officeLocs = await firestore.collection('office_locations').limit(1).get();
      if (officeLocs.docs.isNotEmpty) {
        final docId = officeLocs.docs.first.id;
        await firestore.collection('office_locations').doc(docId).set({
          'name': officeLocs.docs.first.data()['name'] ?? 'OFFICE LOCATION',
          'lat': lat,
          'lng': lng,
          'radius': radius,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else {
        await firestore.collection('office_locations').add({
          'name': 'OFFICE LOCATION',
          'lat': lat,
          'lng': lng,
          'radius': radius,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // 3️⃣ Invalidate in-memory cache
      LocationService.clearCache();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Location & Radius updated in Firebase successfully ✅")),
        );
      }
    } catch (e) {
      _showError("Failed to save location: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("❌ $message"),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  @override
  void dispose() {
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _radiusCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentRadius = double.tryParse(_radiusCtrl.text) ?? 0;
    final kmText = currentRadius >= 1000
        ? "${(currentRadius / 1000).toStringAsFixed(1)} km"
        : "$currentRadius m";

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text("Office Location Settings"),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info banner
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Icon(Icons.info_outline, color: Color(0xFF2563EB)),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "Both 'settings' and 'office_locations' in Firebase will be synchronized. Employees must be within this radius to mark attendance.",
                            style: TextStyle(
                              color: Color(0xFF1E40AF),
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Quick presets
                  const Text(
                    "Quick Location Presets",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.business, size: 16),
                        label: const Text("Vasundhara Bhavan (ONGC)"),
                        onPressed: () => _applyPreset(
                          "Vasundhara Bhavan (ONGC)",
                          19.04525,
                          72.84168,
                          5000,
                        ),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.school, size: 16),
                        label: const Text("Xavier Institute (XIE)"),
                        onPressed: () => _applyPreset(
                          "Xavier Institute of Engineering",
                          19.044953,
                          72.841567,
                          5000,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // GPS button
                  OutlinedButton.icon(
                    onPressed: _fetchingGps ? null : _fetchCurrentGpsLocation,
                    icon: _fetchingGps
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location),
                    label: const Text("Use Current Device GPS Location"),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                    ),
                  ),

                  const SizedBox(height: 20),

                  _field("Office Latitude", _latCtrl, "e.g., 19.04525"),
                  _field("Office Longitude", _lngCtrl, "e.g., 72.84168"),
                  _field(
                    "Allowed Radius (meters)",
                    _radiusCtrl,
                    "e.g., 5000 for 5 km",
                    helperText: "Equivalent to: $kmText",
                  ),

                  const SizedBox(height: 10),

                  // Radius quick buttons
                  const Text(
                    "Quick Radius Selection",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      _radiusChip("500 m", "500"),
                      _radiusChip("1 km", "1000"),
                      _radiusChip("2 km", "2000"),
                      _radiusChip("5 km", "5000"),
                      _radiusChip("10 km", "10000"),
                    ],
                  ),

                  const SizedBox(height: 28),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE11D48),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _loading ? null : _save,
                      child: _loading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              "SAVE LOCATION SETTINGS",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _radiusChip(String label, String value) {
    final isSelected = _radiusCtrl.text.trim() == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() {
          _radiusCtrl.text = value;
        });
      },
    );
  }

  Widget _field(
    String label,
    TextEditingController c,
    String hint, {
    String? helperText,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          helperText: helperText,
          helperStyle: const TextStyle(
            color: Color(0xFF2563EB),
            fontWeight: FontWeight.w600,
          ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
