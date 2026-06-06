import 'dart:convert';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:mobile_app/components/api_class.dart';
// Use 'as geo' to prevent namespace collisions with Mapbox's Position class
import 'package:geolocator/geolocator.dart' as geo;

class CampusMapTab extends StatefulWidget {
  const CampusMapTab({super.key});

  @override
  State<CampusMapTab> createState() => _CampusMapTabState();
}

class _CampusMapTabState extends State<CampusMapTab> {
  MapboxMap? _mapboxMap;
  CircleAnnotationManager? _circleAnnotationManager;
  List<dynamic> _campusLocations = [];
  bool _isLoading = true;

  // NOTE: Replace with your custom Studio Style URL
  final String customStyleUrl = "mapbox://styles/yourusername/custom-style-id";

  @override
  void initState() {
    super.initState();
    _fetchCampusLocations();
  }

  Future<void> _fetchCampusLocations() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final idToken = await user.getIdToken();

      final response = await http.get(
        Uri.parse('${ApiClass().getApiBaseUrl()}/campus-locations/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );

      if (mounted && response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _campusLocations = data is List ? data : (data['results'] ?? []);
          _isLoading = false;
        });

        if (_mapboxMap != null) {
          _drawMapPins();
        }
      }
    } catch (e) {
      debugPrint("Failed to load campus locations: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;

    _circleAnnotationManager = await mapboxMap.annotations
        .createCircleAnnotationManager();

    if (_campusLocations.isNotEmpty) {
      _drawMapPins();
    }
  }

  void _drawMapPins() {
    if (_circleAnnotationManager == null || _campusLocations.isEmpty) return;

    List<CircleAnnotationOptions> options = [];

    for (var loc in _campusLocations) {
      final double lat = loc['latitude'];
      final double lng = loc['longitude'];

      options.add(
        CircleAnnotationOptions(
          // FIX 1: Removed .toJson() so it correctly assigns to the Point type
          // FIX 2: This 'Position' correctly refers to Mapbox because Geolocator is prefixed
          geometry: Point(coordinates: Position(lng, lat)),
          circleRadius: 8.0,
          circleColor: Colors.blueAccent.value,
          circleStrokeWidth: 2.0,
          circleStrokeColor: Colors.white.value,
        ),
      );
    }

    _circleAnnotationManager?.createMulti(options);
  }

  // --- PRODUCTION MEDICAL EMERGENCY LOGIC WITH GEOLOCATOR ---
  Future<void> _triggerMedicalEmergency(BuildContext context) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: const [
            Icon(
              CupertinoIcons.exclamationmark_triangle_fill,
              color: Colors.redAccent,
            ),
            SizedBox(width: 8),
            Text(
              "Emergency Alert",
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ],
        ),
        content: const Text(
          "Are you sure you want to dispatch the medical response team to your current location? Only use this for real emergencies.",
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              "CANCEL",
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              "DISPATCH TEAM",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Colors.redAccent),
      ),
    );

    try {
      // 1. Verify and Request Location Permissions using the 'geo' prefix
      bool serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception("Location services are disabled. Please enable GPS.");
      }

      geo.LocationPermission permission =
          await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
        if (permission == geo.LocationPermission.denied) {
          throw Exception(
            "Location permission denied. Cannot dispatch team to your location.",
          );
        }
      }

      if (permission == geo.LocationPermission.deniedForever) {
        throw Exception(
          "Location permissions are permanently denied. Please enable them in app settings.",
        );
      }

      // 2. Fetch the actual live GPS coordinates using the 'geo' prefix
      final geo.Position position = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
      );

      double lat = position.latitude;
      double lng = position.longitude;

      // 3. Authenticate and POST to Django
      final user = FirebaseAuth.instance.currentUser;
      if (user == null)
        throw Exception("Authentication error. Please log in again.");
      final token = await user.getIdToken();

      final response = await http.post(
        Uri.parse('${ApiClass().getApiBaseUrl()}/emergencies/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          "latitude": lat,
          "longitude": lng,
          "description": "Map-initiated panic alert.",
        }),
      );

      if (response.statusCode != 201) {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['error'] ?? "Server rejected the alert.");
      }

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            "Medical team dispatched to your exact location.",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Failed to send alert: ${e.toString().replaceAll('Exception: ', '')}",
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      body: Stack(
        children: [
          MapWidget(
            key: const ValueKey("campus_mapbox"),
            styleUri: customStyleUrl,
            cameraOptions: CameraOptions(
              // Center exactly over VUT Vanderbijlpark Main Campus
              center: Point(coordinates: Position(27.8157, -26.7398)),
              zoom: 15.5,
              pitch: 45.0,
            ),
            onMapCreated: _onMapCreated,
          ),

          Positioned(
            top: 50,
            left: 24,
            right: 24,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  height: 60,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(CupertinoIcons.search, color: primaryColor),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _isLoading
                              ? "Loading campus data..."
                              : "Search VUT buildings, venues...",
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (_isLoading)
                        SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            color: primaryColor,
                            strokeWidth: 2,
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            CupertinoIcons.location_fill,
                            color: primaryColor,
                            size: 18,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // --- EMERGENCY PANIC BUTTON ---
          Positioned(
            bottom: 120,
            right: 24,
            child: GestureDetector(
              onTap: () => _triggerMedicalEmergency(context),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.redAccent.withOpacity(0.4),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Icon(
                  CupertinoIcons.waveform_path_badge_minus,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
