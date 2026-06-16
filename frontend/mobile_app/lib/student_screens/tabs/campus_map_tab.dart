import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:mobile_app/components/api_class.dart';
import 'package:geolocator/geolocator.dart' as geo;

class CampusMapTab extends StatefulWidget {
  final double? targetLat;
  final double? targetLng;

  const CampusMapTab({super.key, this.targetLat, this.targetLng});

  @override
  State<CampusMapTab> createState() => _CampusMapTabState();
}

class _CampusMapTabState extends State<CampusMapTab> {
  MapboxMap? _mapboxMap;
  CircleAnnotationManager? _circleAnnotationManager;
  PolylineAnnotationManager? _polylineAnnotationManager;

  List<dynamic> _campusLocations = [];
  List<dynamic> _displayedLocations = [];
  geo.Position? _currentUserLocation;
  StreamSubscription<geo.Position>? _positionStreamSubscription;
  geo.Position? _lastRoutedPosition; // NEW: Tracks when to reroute
  bool _isSearching = false;
  bool _isLoading = true;
  bool _isFetchingRoute = false;

  // Navigation State Variables
  Map<String, dynamic>? _activeNavigationPlace;
  bool _hasArrived = false;
  double _liveDistanceToDestination = 0.0;

  final TextEditingController _searchController = TextEditingController();

  final String customStyleUrl =
      "mapbox://styles/kgaogelo-2026/cmqekderb000n01scbhfo3y61";

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    await _fetchCampusLocations();
    await _startLiveLocationTracking();
  }

  Future<void> _startLiveLocationTracking() async {
    try {
      bool serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      geo.LocationPermission permission =
          await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
        if (permission == geo.LocationPermission.denied ||
            permission == geo.LocationPermission.deniedForever) {
          return;
        }
      }

      final geo.Position initialPosition =
          await geo.Geolocator.getCurrentPosition(
            desiredAccuracy: geo.LocationAccuracy.high,
          );

      if (mounted) {
        setState(() {
          _currentUserLocation = initialPosition;
        });
        _calculateNearestPlaces();
      }

      _positionStreamSubscription =
          geo.Geolocator.getPositionStream(
            locationSettings: const geo.LocationSettings(
              accuracy: geo.LocationAccuracy.high,
              distanceFilter: 2,
            ),
          ).listen((geo.Position position) {
            if (mounted) {
              setState(() {
                _currentUserLocation = position;

                if (_activeNavigationPlace != null && !_hasArrived) {
                  double dist = geo.Geolocator.distanceBetween(
                    position.latitude,
                    position.longitude,
                    _activeNavigationPlace!['latitude'],
                    _activeNavigationPlace!['longitude'],
                  );

                  _liveDistanceToDestination = dist;

                  if (dist <= 15.0) {
                    _hasArrived = true;
                  }

                  // --- NEW: DYNAMIC REROUTING LOGIC ---
                  if (!_hasArrived && _lastRoutedPosition != null) {
                    double distanceFromLastRoute =
                        geo.Geolocator.distanceBetween(
                          _lastRoutedPosition!.latitude,
                          _lastRoutedPosition!.longitude,
                          position.latitude,
                          position.longitude,
                        );

                    // If user deviated or walked 25 meters, redraw the line silently
                    if (distanceFromLastRoute > 25.0 && !_isFetchingRoute) {
                      _drawRoute(
                        _activeNavigationPlace!['latitude'],
                        _activeNavigationPlace!['longitude'],
                        autoFrame:
                            false, // Don't snatch the camera from the user
                      );
                    }
                  }
                  // ------------------------------------
                }
              });
            }
          });
    } catch (e) {
      debugPrint("Silent location fetch failed: $e");
    }
  }

  void _calculateNearestPlaces() {
    if (_currentUserLocation == null || _campusLocations.isEmpty) return;

    List<dynamic> sortedLocations = List.from(_campusLocations);

    sortedLocations.sort((a, b) {
      double distA = geo.Geolocator.distanceBetween(
        _currentUserLocation!.latitude,
        _currentUserLocation!.longitude,
        a['latitude'],
        a['longitude'],
      );
      double distB = geo.Geolocator.distanceBetween(
        _currentUserLocation!.latitude,
        _currentUserLocation!.longitude,
        b['latitude'],
        b['longitude'],
      );
      return distA.compareTo(distB);
    });

    setState(() {
      _displayedLocations = sortedLocations.take(5).toList();
      _isSearching = false;
    });
  }

  void _filterPlaces(String query) {
    if (query.isEmpty) {
      _calculateNearestPlaces();
      return;
    }

    setState(() {
      _isSearching = true;
      _displayedLocations = _campusLocations.where((loc) {
        final name = (loc['name'] ?? '').toString().toLowerCase();
        return name.contains(query.toLowerCase());
      }).toList();
    });
  }

  void _frameRouteCamera(double destLat, double destLng) {
    if (_currentUserLocation == null) return;

    final startLat = _currentUserLocation!.latitude;
    final startLng = _currentUserLocation!.longitude;

    // Calculate dynamic midpoint
    double midLat = (startLat + destLat) / 2;
    double midLng = (startLng + destLng) / 2;

    // Calculate maximum difference to determine zoom out level
    double latDiff = (startLat - destLat).abs();
    double lngDiff = (startLng - destLng).abs();
    double maxDiff = latDiff > lngDiff ? latDiff : lngDiff;

    double zoomLevel = 14.0;
    if (maxDiff < 0.002)
      zoomLevel = 16.5; // Very close
    else if (maxDiff < 0.005)
      zoomLevel = 15.5;
    else if (maxDiff < 0.01)
      zoomLevel = 14.5;
    else if (maxDiff < 0.03)
      zoomLevel = 13.5;
    else
      zoomLevel = 12.0;

    _mapboxMap?.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(midLng, midLat)),
        zoom: zoomLevel,
        pitch: 0.0,
        bearing: 0.0,
      ),
      MapAnimationOptions(duration: 1200),
    );
    FocusScope.of(context).unfocus();
  }

  // NEW: Added autoFrame parameter defaulting to true
  Future<void> _drawRoute(
    double destLat,
    double destLng, {
    bool autoFrame = true,
  }) async {
    if (_currentUserLocation == null) return;

    setState(() => _isFetchingRoute = true);

    final startLat = _currentUserLocation!.latitude;
    final startLng = _currentUserLocation!.longitude;

    // Save this spot so we know when to reroute next
    _lastRoutedPosition = _currentUserLocation;

    final url = Uri.parse(
      'https://api.mapbox.com/directions/v5/mapbox/walking/$startLng,$startLat;$destLng,$destLat?geometries=geojson&access_token=${ApiClass.mapboxToken}',
    );

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final routes = data['routes'];

        if (routes != null && routes.isNotEmpty) {
          final geometry = routes[0]['geometry'];
          final coordinates = geometry['coordinates'] as List;

          List<Position> routePoints = coordinates.map((coord) {
            return Position(coord[0], coord[1]);
          }).toList();

          if (routePoints.isNotEmpty) {
            routePoints.insert(0, Position(startLng, startLat));
            routePoints.add(Position(destLng, destLat));
          }

          await _polylineAnnotationManager?.deleteAll();

          _polylineAnnotationManager?.create(
            PolylineAnnotationOptions(
              geometry: LineString(coordinates: routePoints),
              lineColor: Colors.blueAccent.value,
              lineWidth: 6.0,
              lineOpacity: 0.8,
              lineJoin: LineJoin.ROUND,
            ),
          );

          // Only frame the camera on the very first click, not during background rerouting
          if (autoFrame) {
            _frameRouteCamera(destLat, destLng);
          }
        }
      }
    } catch (e) {
      debugPrint("Failed to fetch directions: $e");
    } finally {
      if (mounted) setState(() => _isFetchingRoute = false);
    }
  }

  void _handleLocationSelection(Map<String, dynamic> loc) {
    setState(() {
      _activeNavigationPlace = loc;
      _hasArrived = false;
      if (_currentUserLocation != null) {
        _liveDistanceToDestination = geo.Geolocator.distanceBetween(
          _currentUserLocation!.latitude,
          _currentUserLocation!.longitude,
          loc['latitude'],
          loc['longitude'],
        );
      }
    });

    _drawRoute(loc['latitude'], loc['longitude']);
  }

  void _cancelNavigation() {
    setState(() {
      _activeNavigationPlace = null;
      _hasArrived = false;
    });
    _polylineAnnotationManager?.deleteAll();

    // Recentralize to user upon cancel
    if (_currentUserLocation != null) {
      _mapboxMap?.flyTo(
        CameraOptions(
          center: Point(
            coordinates: Position(
              _currentUserLocation!.longitude,
              _currentUserLocation!.latitude,
            ),
          ),
          zoom: 16.0,
          pitch: 0.0,
        ),
        MapAnimationOptions(duration: 800),
      );
    }
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
          _displayedLocations = List.from(_campusLocations);
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

    await mapboxMap.location.updateSettings(
      LocationComponentSettings(enabled: true, pulsingEnabled: true),
    );

    _circleAnnotationManager = await mapboxMap.annotations
        .createCircleAnnotationManager();
    _polylineAnnotationManager = await mapboxMap.annotations
        .createPolylineAnnotationManager();

    if (_campusLocations.isNotEmpty) {
      _drawMapPins();
    }

    if (widget.targetLat != null && widget.targetLng != null) {
      Future.delayed(const Duration(milliseconds: 500), () {
        // Create a dummy location map for the auto-route
        _handleLocationSelection({
          'name': 'Emergency Target',
          'latitude': widget.targetLat,
          'longitude': widget.targetLng,
        });
      });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B101E),
      body: Stack(
        children: [
          Positioned.fill(
            child: MapWidget(
              key: const ValueKey("campus_mapbox"),
              styleUri: customStyleUrl,
              viewport: CameraViewportState(
                center: Point(coordinates: Position(27.866326, -26.716744)),
                zoom: 12,
              ),
              onMapCreated: _onMapCreated,
            ),
          ),

          // =================================================================
          // DEFAULT STATE: Search Bar & Location List
          // =================================================================
          if (_activeNavigationPlace == null) ...[
            // Glassmorphism Search Bar
            Positioned(
              top: 50,
              left: 24,
              right: 24,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    height: 60,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Icon(
                            CupertinoIcons.arrow_left,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(
                          CupertinoIcons.search,
                          color: Colors.white54,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            onChanged: _filterPlaces,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: InputDecoration(
                              hintText: _isLoading
                                  ? "Loading campus data..."
                                  : "Search VUT buildings...",
                              hintStyle: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontWeight: FontWeight.w600,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        if (_searchController.text.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              _filterPlaces('');
                              FocusScope.of(context).unfocus();
                            },
                            child: const Icon(
                              CupertinoIcons.clear_thick_circled,
                              color: Colors.white54,
                              size: 20,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Bottom Sheet: List of Locations
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    height: 280,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.15),
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 30,
                          offset: const Offset(0, -10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            margin: const EdgeInsets.only(top: 12, bottom: 8),
                            height: 5,
                            width: 48,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24.0,
                            vertical: 8.0,
                          ),
                          child: Text(
                            _isSearching
                                ? "Search Results"
                                : "Top 5 Nearest Places",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        Expanded(
                          child: _isLoading
                              ? const Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.blueAccent,
                                  ),
                                )
                              : _displayedLocations.isEmpty
                              ? Center(
                                  child: Text(
                                    "No locations found.",
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.5),
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.only(bottom: 20),
                                  itemCount: _displayedLocations.length,
                                  separatorBuilder: (context, index) => Divider(
                                    color: Colors.white.withOpacity(0.1),
                                    height: 1,
                                    indent: 72,
                                  ),
                                  itemBuilder: (context, index) {
                                    final loc = _displayedLocations[index];
                                    return ListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 24,
                                            vertical: 8,
                                          ),
                                      leading: Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.blueAccent.withOpacity(
                                            0.2,
                                          ),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.blueAccent
                                                .withOpacity(0.5),
                                          ),
                                        ),
                                        child: const Icon(
                                          CupertinoIcons.location_solid,
                                          color: Colors.blueAccent,
                                          size: 20,
                                        ),
                                      ),
                                      title: Text(
                                        loc['name'] ?? 'Unknown Building',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                        ),
                                      ),
                                      subtitle:
                                          _isSearching == false &&
                                              _currentUserLocation != null
                                          ? Text(
                                              "${(geo.Geolocator.distanceBetween(_currentUserLocation!.latitude, _currentUserLocation!.longitude, loc['latitude'], loc['longitude']) / 1000).toStringAsFixed(2)} km away",
                                              style: TextStyle(
                                                color: Colors.white.withOpacity(
                                                  0.5,
                                                ),
                                                fontSize: 13,
                                              ),
                                            )
                                          : null,
                                      trailing: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              Colors.green.shade600,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 8,
                                          ),
                                        ),
                                        onPressed: () =>
                                            _handleLocationSelection(loc),
                                        child: const Text(
                                          "GO",
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 12,
                                            letterSpacing: 1.0,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ]
          // =================================================================
          // ACTIVE NAVIGATION STATE: Top Banner & Bottom Route Tracker
          // =================================================================
          else ...[
            // Top Navigation Banner
            Positioned(
              top: 50,
              left: 24,
              right: 24,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade700,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(
                      CupertinoIcons.arrow_turn_up_right,
                      color: Colors.white,
                      size: 28,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "NAVIGATING TO",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                            ),
                          ),
                          Text(
                            _activeNavigationPlace!['name'] ??
                                'Target Location',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Route Status Panel
            Positioned(
              bottom: 40,
              left: 24,
              right: 24,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: _hasArrived
                          ? Colors.green.shade900.withOpacity(0.9)
                          : Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: _hasArrived
                            ? Colors.green.shade400
                            : Colors.white.withOpacity(0.2),
                        width: 1.0,
                      ),
                    ),
                    child: _hasArrived
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                CupertinoIcons.checkmark_seal_fill,
                                color: Colors.greenAccent,
                                size: 64,
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                "SUCCESSFULLY ARRIVED",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "You have reached ${_activeNavigationPlace!['name']}.",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.green.shade900,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  onPressed: _cancelNavigation,
                                  child: const Text(
                                    "END NAVIGATION",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_isFetchingRoute)
                                const Padding(
                                  padding: EdgeInsets.only(bottom: 16),
                                  child: LinearProgressIndicator(
                                    color: Colors.blueAccent,
                                  ),
                                ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        "DISTANCE REMAINING",
                                        style: TextStyle(
                                          color: Colors.white54,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                                      Text(
                                        _liveDistanceToDestination > 1000
                                            ? "${(_liveDistanceToDestination / 1000).toStringAsFixed(2)} km"
                                            : "${_liveDistanceToDestination.toInt()} meters",
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 24,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.redAccent
                                          .withOpacity(0.2),
                                      foregroundColor: Colors.redAccent,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        side: const BorderSide(
                                          color: Colors.redAccent,
                                        ),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 14,
                                      ),
                                    ),
                                    onPressed: _cancelNavigation,
                                    child: const Text(
                                      "CANCEL",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
