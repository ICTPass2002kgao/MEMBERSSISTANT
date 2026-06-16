import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mobile_app/components/api_class.dart';

class EmergencyBubbleBackground extends StatelessWidget {
  const EmergencyBubbleBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -80,
          left: -50,
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  Colors.redAccent.withOpacity(0.8),
                  Colors.redAccent.withOpacity(0.4),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.redAccent.withOpacity(0.3),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: -100,
          right: -80,
          child: Container(
            width: 320,
            height: 320,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  Colors.orange.withOpacity(0.6),
                  Colors.red.withOpacity(0.6),
                ],
                begin: Alignment.bottomRight,
                end: Alignment.topLeft,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withOpacity(0.2),
                  blurRadius: 40,
                  spreadRadius: 5,
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 250,
          right: -60,
          child: Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  Colors.deepOrangeAccent.withOpacity(0.7),
                  Colors.redAccent.withOpacity(0.5),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.2),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class EmergencyReportingScreen extends StatefulWidget {
  const EmergencyReportingScreen({super.key});

  @override
  State<EmergencyReportingScreen> createState() =>
      _EmergencyReportingScreenState();
}

class _EmergencyReportingScreenState extends State<EmergencyReportingScreen> {
  File? _capturedImage;
  String _selectedEmergency = 'Collapsed';
  final TextEditingController _descController = TextEditingController();

  bool _isSubmitting = false;
  int _locationMethod = 0; // 0 = Live GPS, 1 = Specific Room

  // Location Hierarchy State
  List<dynamic> _accommodations = [];
  List<dynamic> _blocks = [];
  List<dynamic> _rooms = [];

  dynamic _selectedAccommodation;
  dynamic _selectedBlock;
  dynamic _selectedRoom;

  bool _isLoadingAccommodations = false;
  bool _isLoadingBlocks = false;
  bool _isLoadingRooms = false;

  final List<String> _emergencyTypes = [
    'Collapsed',
    'Bleeding/Injury',
    'Seizure',
    'Breathing Issues',
    'Fire',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _captureImage();
    });
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _captureImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 80,
    );

    if (image != null) {
      setState(() {
        _capturedImage = File(image.path);
      });
    }
  }

  Future<void> _fetchAccommodations() async {
    if (_accommodations.isNotEmpty) return; // Prevent refetching

    setState(() => _isLoadingAccommodations = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final token = await user.getIdToken();

      final response = await http.get(
        Uri.parse('${ApiClass().getApiBaseUrl()}/accommodations/'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _accommodations = data is List ? data : (data['results'] ?? []);
          });
        }
      }
    } catch (e) {
      _showError('Failed to load accommodations.');
    } finally {
      if (mounted) setState(() => _isLoadingAccommodations = false);
    }
  }

  Future<void> _fetchBlocks(String accommodationId) async {
    setState(() {
      _blocks = [];
      _rooms = [];
      _selectedBlock = null;
      _selectedRoom = null;
      _isLoadingBlocks = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final token = await user.getIdToken();

      final response = await http.get(
        Uri.parse(
          '${ApiClass().getApiBaseUrl()}/blocks/?accommodation__id=$accommodationId',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _blocks = data is List ? data : (data['results'] ?? []);
          });
        }
      }
    } catch (e) {
      _showError('Failed to load blocks.');
    } finally {
      if (mounted) setState(() => _isLoadingBlocks = false);
    }
  }

  Future<void> _fetchRooms(String blockId) async {
    setState(() {
      _rooms = [];
      _selectedRoom = null;
      _isLoadingRooms = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final token = await user.getIdToken();

      final response = await http.get(
        Uri.parse('${ApiClass().getApiBaseUrl()}/rooms/?block__id=$blockId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _rooms = data is List ? data : (data['results'] ?? []);
          });
        }
      }
    } catch (e) {
      _showError('Failed to load rooms.');
    } finally {
      if (mounted) setState(() => _isLoadingRooms = false);
    }
  }

  Future<void> _submitEmergency() async {
    if (_capturedImage == null) {
      _showError('Please capture a photo of the situation.');
      return;
    }

    if (_locationMethod == 1 &&
        (_selectedAccommodation == null ||
            _selectedBlock == null ||
            _selectedRoom == null)) {
      _showError('Please select the Accommodation, Block, and Room.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // 1. Fetch GPS coordinates silently regardless of method (Fallback to 0.0 if denied)
      double lat = 0.0;
      double lng = 0.0;

      try {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (serviceEnabled) {
          LocationPermission permission = await Geolocator.checkPermission();
          if (permission != LocationPermission.denied &&
              permission != LocationPermission.deniedForever) {
            Position position = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high,
            );
            lat = position.latitude;
            lng = position.longitude;
          }
        }
      } catch (_) {
        // Silently ignore GPS failure if they chose manual room entry
        if (_locationMethod == 0)
          throw Exception("GPS is required when 'Live GPS Only' is selected.");
      }

      // 2. Prepare Payload
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not authenticated.");
      final idToken = await user.getIdToken();

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiClass().getApiBaseUrl()}/emergencies/create/'),
      );

      request.headers.addAll({'Authorization': 'Bearer $idToken'});

      request.fields['emergency_type'] = _selectedEmergency;

      // Inject Room Details into description if provided
      String finalDescription = _descController.text.trim();
      if (_locationMethod == 1) {
        finalDescription =
            "[MANUAL LOCATION: ${_selectedAccommodation['name']} - Block ${_selectedBlock['name']}, Room ${_selectedRoom['room_number']}]\n$finalDescription";
      }

      request.fields['description'] = finalDescription;
      request.fields['latitude'] = lat.toString();
      request.fields['longitude'] = lng.toString();

      request.files.add(
        await http.MultipartFile.fromPath(
          'situation_image',
          _capturedImage!.path,
        ),
      );

      // 3. Send Request
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201) {
        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              "Emergency Alert Sent! Medical team dispatched.",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            backgroundColor: Colors.green.shade600,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        throw Exception(
          "Failed to send alert. Server responded with ${response.statusCode}",
        );
      }
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.redAccent.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = theme.scaffoldBackgroundColor;
    final textColor = theme.colorScheme.onSurface;

    return Scaffold(
      backgroundColor: bgColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          "Medical Emergency",
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: Colors.redAccent,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: Stack(
        children: [
          const EmergencyBubbleBackground(),
          SafeArea(
            child: _isSubmitting
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.redAccent),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24.0,
                      vertical: 16.0,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(40),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: Container(
                          padding: const EdgeInsets.all(28.0),
                          decoration: BoxDecoration(
                            color: bgColor.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(40),
                            border: Border.all(
                              color: Colors.redAccent.withOpacity(0.3),
                              width: 1.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 40,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Glass Image Container
                              GestureDetector(
                                onTap: _captureImage,
                                child: Container(
                                  height: 180,
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: Colors.redAccent.withOpacity(0.4),
                                      width: 1.5,
                                    ),
                                    image: _capturedImage != null
                                        ? DecorationImage(
                                            image: FileImage(_capturedImage!),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                  ),
                                  child: _capturedImage == null
                                      ? Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              CupertinoIcons.camera_fill,
                                              size: 40,
                                              color: Colors.redAccent
                                                  .withOpacity(0.8),
                                            ),
                                            const SizedBox(height: 12),
                                            Text(
                                              "Capture Patient / Situation",
                                              style: TextStyle(
                                                fontWeight: FontWeight.w800,
                                                color: textColor.withOpacity(
                                                  0.7,
                                                ),
                                              ),
                                            ),
                                          ],
                                        )
                                      : Align(
                                          alignment: Alignment.bottomRight,
                                          child: Padding(
                                            padding: const EdgeInsets.all(12.0),
                                            child: Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: Colors.black54,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.refresh,
                                                color: Colors.white,
                                                size: 24,
                                              ),
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 24),

                              Text(
                                "Nature of Emergency",
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.transparent),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    isExpanded: true,
                                    value: _selectedEmergency,
                                    dropdownColor: bgColor,
                                    icon: const Icon(
                                      CupertinoIcons.chevron_down,
                                      color: Colors.redAccent,
                                    ),
                                    items: _emergencyTypes.map((String value) {
                                      return DropdownMenuItem<String>(
                                        value: value,
                                        child: Text(
                                          value,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: textColor,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (newValue) => setState(
                                      () => _selectedEmergency = newValue!,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),

                              // LOCATION TOGGLE
                              Text(
                                "Location Tracking",
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 12),
                              CupertinoSlidingSegmentedControl<int>(
                                groupValue: _locationMethod,
                                thumbColor: Colors.redAccent.withOpacity(0.2),
                                backgroundColor: Colors.grey.withOpacity(0.1),
                                children: {
                                  0: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    child: Text(
                                      "📍 Live GPS Only",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: _locationMethod == 0
                                            ? Colors.redAccent
                                            : textColor.withOpacity(0.6),
                                      ),
                                    ),
                                  ),
                                  1: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    child: Text(
                                      "🏢 Specific Room",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: _locationMethod == 1
                                            ? Colors.redAccent
                                            : textColor.withOpacity(0.6),
                                      ),
                                    ),
                                  ),
                                },
                                onValueChanged: (value) {
                                  setState(() => _locationMethod = value!);
                                  if (value == 1) _fetchAccommodations();
                                },
                              ),

                              // CONDITIONAL DYNAMIC LOCATION INPUTS
                              if (_locationMethod == 1) ...[
                                const SizedBox(height: 16),

                                // ACCOMMODATION DROPDOWN
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<dynamic>(
                                      isExpanded: true,
                                      hint: Text(
                                        _isLoadingAccommodations
                                            ? "Loading..."
                                            : "Select Accommodation",
                                        style: TextStyle(
                                          color: textColor.withOpacity(0.4),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      value: _selectedAccommodation,
                                      dropdownColor: bgColor,
                                      icon: const Icon(
                                        CupertinoIcons.chevron_down,
                                        color: Colors.redAccent,
                                      ),
                                      items: _accommodations.map((dynamic acc) {
                                        return DropdownMenuItem<dynamic>(
                                          value: acc,
                                          child: Text(
                                            acc['name'],
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: textColor,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (newValue) {
                                        setState(() {
                                          _selectedAccommodation = newValue;
                                        });
                                        if (newValue != null) {
                                          _fetchBlocks(newValue['id']);
                                        }
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // BLOCK DROPDOWN
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<dynamic>(
                                      isExpanded: true,
                                      hint: Text(
                                        _isLoadingBlocks
                                            ? "Loading..."
                                            : "Select Block",
                                        style: TextStyle(
                                          color: textColor.withOpacity(0.4),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      value: _selectedBlock,
                                      dropdownColor: bgColor,
                                      icon: const Icon(
                                        CupertinoIcons.chevron_down,
                                        color: Colors.redAccent,
                                      ),
                                      items: _blocks.map((dynamic block) {
                                        return DropdownMenuItem<dynamic>(
                                          value: block,
                                          child: Text(
                                            block['name'],
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: textColor,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: _selectedAccommodation == null
                                          ? null
                                          : (newValue) {
                                              setState(() {
                                                _selectedBlock = newValue;
                                              });
                                              if (newValue != null) {
                                                _fetchRooms(newValue['id']);
                                              }
                                            },
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // ROOM DROPDOWN
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<dynamic>(
                                      isExpanded: true,
                                      hint: Text(
                                        _isLoadingRooms
                                            ? "Loading..."
                                            : "Select Room",
                                        style: TextStyle(
                                          color: textColor.withOpacity(0.4),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      value: _selectedRoom,
                                      dropdownColor: bgColor,
                                      icon: const Icon(
                                        CupertinoIcons.chevron_down,
                                        color: Colors.redAccent,
                                      ),
                                      items: _rooms.map((dynamic room) {
                                        return DropdownMenuItem<dynamic>(
                                          value: room,
                                          child: Text(
                                            "Room ${room['room_number']}",
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: textColor,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: _selectedBlock == null
                                          ? null
                                          : (newValue) {
                                              setState(() {
                                                _selectedRoom = newValue;
                                              });
                                            },
                                    ),
                                  ),
                                ),
                              ],

                              const SizedBox(height: 24),

                              Text(
                                "Additional Details",
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _descController,
                                maxLines: 3,
                                style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.w600,
                                ),
                                decoration: InputDecoration(
                                  hintText: "Type any extra details...",
                                  hintStyle: TextStyle(
                                    color: textColor.withOpacity(0.4),
                                  ),
                                  filled: true,
                                  fillColor: Colors.redAccent.withOpacity(0.05),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 32),

                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton.icon(
                                  onPressed: _submitEmergency,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.redAccent,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 8,
                                    shadowColor: Colors.redAccent.withOpacity(
                                      0.5,
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.warning_rounded,
                                    color: Colors.white,
                                  ),
                                  label: const Text(
                                    "DISPATCH TEAM",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
