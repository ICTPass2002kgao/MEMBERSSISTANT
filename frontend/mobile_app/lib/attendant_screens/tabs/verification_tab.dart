// ignore_for_file: prefer_const_constructors, use_build_context_synchronously, avoid_print

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/components/api_class.dart';

import 'package:mobile_app/components/liveness_wrapper.dart'
    if (dart.library.io) '/components/liveness_wrapper_mobile.dart'
    if (dart.library.html) '/components/liveness_wrapper_web.dart';

class AttendantVerificationTab extends StatefulWidget {
  const AttendantVerificationTab({super.key});

  @override
  State<AttendantVerificationTab> createState() =>
      _AttendantVerificationTabState();
}

class _AttendantVerificationTabState extends State<AttendantVerificationTab> {
  bool _isLoading = true;
  List<dynamic> _blocks = [];
  List<dynamic> _units = [];
  List<dynamic> _rooms = [];
  List<dynamic> _students = [];

  // Search Controller & Query
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _fetchHierarchyData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchHierarchyData() async {
    setState(() => _isLoading = true);
    try {
      final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
      final headers = {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      };

      final baseUrl = ApiClass().getApiBaseUrl();

      final responses = await Future.wait([
        http.get(Uri.parse('$baseUrl/blocks/'), headers: headers),
        http.get(Uri.parse('$baseUrl/units/'), headers: headers),
        http.get(Uri.parse('$baseUrl/rooms/'), headers: headers),
        http.get(Uri.parse('$baseUrl/students/'), headers: headers),
      ]);

      if (mounted) {
        setState(() {
          _blocks = _extractData(responses[0].body);
          _units = _extractData(responses[1].body);
          _rooms = _extractData(responses[2].body);
          _students = _extractData(responses[3].body);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<dynamic> _extractData(String responseBody) {
    final decoded = jsonDecode(responseBody);
    return decoded is List ? decoded : (decoded['results'] ?? []);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final textColor = theme.colorScheme.onSurface;

    if (_isLoading)
      return Center(child: CircularProgressIndicator(color: primaryColor));

    // Only show students who are unverified
    final unverifiedStudents = _students
        .where((s) => s['verification_status'] == false && s['room'] != null)
        .toList();

    if (unverifiedStudents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.checkmark_shield_fill,
              size: 80,
              color: Colors.green.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              "All Clear!",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "No pending room verifications.",
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "ROOM VERIFICATIONS",
          style: TextStyle(
            color: primaryColor,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // --- UPDATED SEARCH BAR ---
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: "Search room or student name...",
                hintStyle: TextStyle(color: Colors.grey.shade500),
                prefixIcon: Icon(CupertinoIcons.search, color: primaryColor),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          CupertinoIcons.clear_thick_circled,
                          color: Colors.grey,
                          size: 18,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = "");
                        },
                      )
                    : null,
                filled: true,
                fillColor: primaryColor.withOpacity(0.05),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // --- LIST VIEW ---
          Expanded(
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _blocks.length,
              itemBuilder: (context, index) {
                final block = _blocks[index];

                final blockRoomsWithPending = _rooms.where((room) {
                  if (room['block'] != block['id']) return false;

                  // Get specific students for this room
                  final targetStudents = unverifiedStudents
                      .where((s) => s['room'] == room['id'])
                      .toList();
                  if (targetStudents.isEmpty) return false;

                  // SEARCH LOGIC: Match Room Number OR Student Name
                  if (_searchQuery.isNotEmpty) {
                    String roomNo = room['room_number']
                        .toString()
                        .toLowerCase();
                    bool studentMatch = targetStudents.any((s) {
                      String fullName = "${s['name']} ${s['surname']}"
                          .toLowerCase();
                      return fullName.contains(_searchQuery);
                    });

                    if (!roomNo.contains(_searchQuery) && !studentMatch)
                      return false;
                  }

                  return true;
                }).toList();

                if (blockRoomsWithPending.isEmpty)
                  return const SizedBox.shrink();

                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: primaryColor.withOpacity(0.1)),
                  ),
                  child: ExpansionTile(
                    initiallyExpanded: _searchQuery.isNotEmpty,
                    collapsedShape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    backgroundColor: primaryColor.withOpacity(0.02),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        CupertinoIcons.building_2_fill,
                        color: primaryColor,
                      ),
                    ),
                    title: Text(
                      block['name'],
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Text(
                      "${blockRoomsWithPending.length} matching room(s)",
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    children: blockRoomsWithPending.map((room) {
                      String unitName = "Direct to Block";
                      if (room['unit'] != null) {
                        final u = _units.firstWhere(
                          (u) => u['id'] == room['unit'],
                          orElse: () => null,
                        );
                        if (u != null) unitName = u['name'];
                      }

                      final targetStudents = unverifiedStudents
                          .where((s) => s['room'] == room['id'])
                          .toList();

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 8,
                        ),
                        title: Row(
                          children: [
                            Text(
                              "Room ${room['room_number']}",
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.purple.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                unitName,
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: Colors.purple,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        // SHOW MINI-AVATARS OF STUDENTS IN THE SUBTITLE
                        subtitle: Row(
                          children: [
                            ...targetStudents
                                .take(3)
                                .map(
                                  (s) => Padding(
                                    padding: const EdgeInsets.only(
                                      right: 4.0,
                                      top: 6.0,
                                    ),
                                    child: CircleAvatar(
                                      radius: 10,
                                      backgroundColor: primaryColor.withOpacity(
                                        0.2,
                                      ),
                                      backgroundImage: s['face_url'] != null
                                          ? NetworkImage(s['face_url'])
                                          : null,
                                      child: s['face_url'] == null
                                          ? Icon(
                                              CupertinoIcons.person_fill,
                                              size: 12,
                                              color: primaryColor,
                                            )
                                          : null,
                                    ),
                                  ),
                                ),
                            if (targetStudents.length > 3)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 6.0,
                                  right: 4.0,
                                ),
                                child: Text(
                                  "+${targetStudents.length - 3}",
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            const SizedBox(width: 4),
                            Padding(
                              padding: const EdgeInsets.only(top: 6.0),
                              child: Text(
                                "${targetStudents.length} pending",
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        trailing: const Icon(
                          CupertinoIcons.chevron_right,
                          size: 16,
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            CupertinoPageRoute(
                              builder: (context) => StudentRoomSelectionScreen(
                                room: room,
                                students: targetStudents,
                                onVerified: _fetchHierarchyData,
                              ),
                            ),
                          );
                        },
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class StudentRoomSelectionScreen extends StatelessWidget {
  final dynamic room;
  final List<dynamic> students;
  final VoidCallback onVerified;

  const StudentRoomSelectionScreen({
    super.key,
    required this.room,
    required this.students,
    required this.onVerified,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
        title: Text(
          "ROOM ${room['room_number']}",
          style: TextStyle(color: primaryColor, fontWeight: FontWeight.w900),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(24),
        itemCount: students.length,
        itemBuilder: (context, index) {
          final student = students[index];

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.red.withOpacity(0.3), width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // ACTUAL STUDENT FACE INSTEAD OF PLACEHOLDER
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: student['face_url'] != null
                      ? NetworkImage(student['face_url'])
                      : null,
                  child: student['face_url'] == null
                      ? const Icon(
                          CupertinoIcons.person_solid,
                          size: 40,
                          color: Colors.grey,
                        )
                      : null,
                ),
                const SizedBox(height: 16),
                Text(
                  "${student['name']} ${student['surname']}",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  "ID: ${student['student_number']}",
                  style: const TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        CupertinoPageRoute(
                          builder: (context) => NeumorphicVerificationScanner(
                            student: student,
                            onVerified: () {
                              onVerified();
                              Navigator.pop(context);
                            },
                          ),
                        ),
                      );
                    },
                    icon: const Icon(CupertinoIcons.camera_viewfinder),
                    label: const Text(
                      "SCAN FACE",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ================================================================================================
// NEUMORPHIC SCANNER SCREEN
// ================================================================================================


class NeumorphicVerificationScanner extends StatefulWidget {
  final dynamic student;
  final VoidCallback onVerified;

  const NeumorphicVerificationScanner({
    super.key,
    required this.student,
    required this.onVerified,
  });

  @override
  State<NeumorphicVerificationScanner> createState() =>
      _NeumorphicVerificationScannerState();
}

class _NeumorphicVerificationScannerState
    extends State<NeumorphicVerificationScanner>
    with SingleTickerProviderStateMixin {
  CameraController? _cameraController;
  bool _isVerifying = false;
  bool _isVerifyingLiveness = false;
  String _processStatus = "Initializing...";
  bool _isCameraInitialized = false;
  late AnimationController _scannerController;

  @override
  void initState() {
    super.initState();
    _scannerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    if (!kIsWeb) {
      var status = await Permission.camera.status;
      if (!status.isGranted) {
        await Permission.camera.request();
      }
    }
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw Exception("No cameras found");

      CameraDescription targetCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        targetCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await _cameraController!.initialize();
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
          _processStatus = "Ready";
        });
      }
    } catch (e) {
      if (mounted) setState(() => _processStatus = "Camera Error: $e");
    }
  }

  // --- Mobile Secure Flow ---
  Future<void> _startLivenessCapture() async {
    await _cameraController?.dispose();
    _cameraController = null;

    setState(() {
      _isCameraInitialized = false;
      _isVerifyingLiveness = true;
      _processStatus = 'Follow on-screen instructions...';
    });
  }

  // --- Web Fallback Flow ---
  Future<void> _captureWebAndVerify() async {
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized ||
        _isVerifying)
      return;

    setState(() {
      _isVerifying = true;
      _processStatus = 'Scanning Image...';
    });

    try {
      final XFile capturedFile = await _cameraController!.takePicture();
      if (mounted) await _cameraController?.pausePreview();
      final Uint8List capturedBytes = await capturedFile.readAsBytes();

      await _processBackendMatch(capturedBytes);
    } catch (e) {
      _handleFailure(reason: "Web Camera Capture Error");
    }
  }

  // --- Shared Backend Match Logic ---
  Future<void> _processBackendMatch(Uint8List capturedBytes) async {
    setState(() {
      _isVerifying = true;
      _processStatus = 'Scanning Biometrics...';
    });

    try {
      final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();

      var request = http.MultipartRequest(
        'POST',
        Uri.parse(
          '${ApiClass().getApiBaseUrl()}/verify-student-presence/${widget.student['id']}/',
        ),
      );

      request.headers['Authorization'] = 'Bearer $idToken';
      request.files.add(
        http.MultipartFile.fromBytes(
          'live_face',
          capturedBytes,
          filename: 'face_scan.jpg',
        ),
      );

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("${widget.student['name']} successfully verified!"),
            backgroundColor: Colors.green,
          ),
        );
        widget.onVerified();
        if (mounted) Navigator.pop(context);
      } else {
        final errorData = jsonDecode(response.body);
        _handleFailure(reason: errorData['error'] ?? "Biometric mismatch.");
      }
    } catch (e) {
      _cameraController?.resumePreview();
      _handleFailure(reason: "Camera/Network Error");
    }
  }

  void _handleFailure({required String reason}) async {
    if (!mounted) return;
    setState(() {
      _isVerifying = false;
      _isVerifyingLiveness = false;
      _processStatus = "Failed: $reason";
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(reason), backgroundColor: Colors.redAccent),
    );

    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() {
        _isVerifying = false;
        _processStatus = "Ready";
      });
      if (!_isCameraInitialized && !_isVerifyingLiveness) {
        _initializeCamera();
      }
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  Widget _buildNeumorphicContainer({
    required Widget child,
    required Color baseColor,
    required EdgeInsets padding,
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(5, 5),
          ),
          BoxShadow(
            color: Colors.white,
            blurRadius: 10,
            offset: const Offset(-5, -5),
          ),
        ],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color baseColor = Colors.grey.shade200;
    final Color primaryColor = theme.colorScheme.primary;
    final Color textColor = Colors.black87;
    final Color hintColor = Colors.grey;

    return Scaffold(
      backgroundColor: baseColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Verification',
          style: GoogleFonts.poppins(
            color: textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildNeumorphicContainer(
                baseColor: baseColor,
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      height: 60,
                      width: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: hintColor.withOpacity(0.3)),
                        image: widget.student['face_url'] != null
                            ? DecorationImage(
                                image: NetworkImage(widget.student['face_url']),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: widget.student['face_url'] == null
                          ? Icon(Icons.person, color: hintColor)
                          : null,
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Student Verification",
                            style: GoogleFonts.poppins(
                              color: textColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            "${widget.student['name']} ${widget.student['surname']}",
                            style: GoogleFonts.poppins(
                              color: hintColor,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              if (_isVerifying)
                _buildProcessingPanel(baseColor, textColor, primaryColor)
              else
                _buildLiveCamPanel(baseColor, textColor, primaryColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLiveCamPanel(
    Color baseColor,
    Color textColor,
    Color primaryColor,
  ) {
    return _buildNeumorphicContainer(
      baseColor: baseColor,
      padding: const EdgeInsets.all(24),
      child: Column(
        children: <Widget>[
          Row(
            children: [
              Container(
                height: 25,
                width: 4,
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                "Live Scan",
                style: GoogleFonts.poppins(
                  fontSize: 18.0,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _isVerifyingLiveness
                ? 'Follow instructions within the frame.'
                : (_isCameraInitialized
                    ? 'Align student face within the frame.'
                    : 'Initializing camera system...'),
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: textColor.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 40),
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 240,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [baseColor.withOpacity(0.5), baseColor],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(10, 10),
                    ),
                    BoxShadow(
                      color: Colors.white,
                      blurRadius: 20,
                      offset: const Offset(-5, -5),
                    ),
                  ],
                ),
              ),
              ClipOval(
                child: Container(
                  width: 220,
                  height: 300,
                  color: Colors.black,
                  child: (!kIsWeb && _isVerifyingLiveness)
                      ? getLivenessWidget(
                          onSuccess: (result) async {
                            setState(() {
                              _isVerifyingLiveness = false;
                              _isVerifying = true;
                              _processStatus = 'Capturing secure image...';
                            });

                            try {
                              Uint8List? capturedBytes;
                              dynamic res = result;

                              if (res is Uint8List) {
                                capturedBytes = res;
                              } else {
                                try {
                                  capturedBytes ??= res.imageBytes;
                                } catch (_) {}
                                try {
                                  capturedBytes ??= res.capturedImage;
                                } catch (_) {}
                                try {
                                  capturedBytes ??= res.jpegBytes;
                                } catch (_) {}
                                try {
                                  capturedBytes ??= res.image;
                                } catch (_) {}

                                if (capturedBytes == null) {
                                  String? path;
                                  try {
                                    path ??= res.imagePath;
                                  } catch (_) {}
                                  try {
                                    path ??= res.path;
                                  } catch (_) {}

                                  if (path != null && path.isNotEmpty) {
                                    final file = File(path);
                                    capturedBytes = await file.readAsBytes();
                                  }
                                }
                              }

                              if (capturedBytes == null) {
                                print(
                                  "Package didn't provide an image. Waiting for hardware release...",
                                );

                                await Future.delayed(
                                  const Duration(milliseconds: 600),
                                );

                                if (_cameraController == null ||
                                    !_cameraController!.value.isInitialized) {
                                  final cameras = await availableCameras();
                                  CameraDescription targetCamera = cameras
                                      .firstWhere(
                                        (camera) =>
                                            camera.lensDirection ==
                                            CameraLensDirection.front,
                                        orElse: () => cameras.first,
                                      );

                                  _cameraController = CameraController(
                                    targetCamera,
                                    ResolutionPreset.medium,
                                    enableAudio: false,
                                  );
                                  await _cameraController!.initialize();
                                }

                                await Future.delayed(
                                  const Duration(milliseconds: 200),
                                );

                                final XFile capturedFile =
                                    await _cameraController!.takePicture();
                                capturedBytes = await capturedFile
                                    .readAsBytes();
                              }

                              if (capturedBytes != null) {
                                await _processBackendMatch(capturedBytes);
                              } else {
                                _handleFailure(
                                  reason:
                                      "Camera hardware failed to capture image.",
                                );
                              }
                            } catch (e) {
                              print("CRITICAL ERROR: $e");
                              _handleFailure(
                                reason: "Secure capture failed: $e",
                              );
                            }
                          },
                          onFailed: (reason) {
                            _handleFailure(
                              reason: "Spoofing Detected: $reason",
                            );
                          },
                        )
                      : (_isCameraInitialized
                          ? AspectRatio(
                              aspectRatio: _cameraController!.value.aspectRatio,
                              child: CameraPreview(_cameraController!),
                            )
                          : Center(
                              child: CircularProgressIndicator(color: primaryColor),
                            )),
                ),
              ),
              if (_isCameraInitialized && !_isVerifyingLiveness)
                Positioned.fill(
                  child: ClipOval(
                    child: AnimatedBuilder(
                      animation: _scannerController,
                      builder: (context, child) {
                        return Align(
                          alignment: Alignment(
                            0,
                            _scannerController.value * 2 - 1,
                          ),
                          child: Container(
                            height: 4,
                            width: 220,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  Colors.green,
                                  Colors.green,
                                  Colors.green.withOpacity(0.8),
                                  Colors.transparent,
                                ],
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.green,
                                  blurRadius: 15,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 40),
          if (!_isVerifyingLiveness)
            GestureDetector(
              onTap: kIsWeb ? _captureWebAndVerify : _startLivenessCapture,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    'Start Face Match',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProcessingPanel(
    Color baseColor,
    Color textColor,
    Color primaryColor,
  ) {
    return _buildNeumorphicContainer(
      baseColor: baseColor,
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder(
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(milliseconds: 1000),
              builder: (context, val, _) {
                return Transform.scale(
                  scale: 1.0 + (0.1 * val),
                  child: Container(
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: baseColor,
                      border: Border.all(
                        color: primaryColor.withOpacity(0.5),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withOpacity(0.2),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.fingerprint_outlined,
                      size: 60,
                      color: primaryColor,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 40),
            Text(
              "Processing...",
              style: GoogleFonts.poppins(
                color: textColor,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _processStatus,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: Colors.green, fontSize: 14),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: 150,
              child: LinearProgressIndicator(
                backgroundColor: baseColor,
                color: Colors.green,
                minHeight: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}