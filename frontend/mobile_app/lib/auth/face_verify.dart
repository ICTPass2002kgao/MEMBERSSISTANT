import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'dart:ui';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_app/auth/login.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../components/liveness_wrapper.dart'
    if (dart.library.io) '../components/liveness_wrapper_mobile.dart'
    if (dart.library.html) '../components/liveness_wrapper_web.dart';

import 'package:mobile_app/components/api_class.dart'; 
class LandlordFaceVerificationScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  final Uint8List contractPdfBytes;
  final Uint8List idDocumentBytes;
  final String idDocumentName;
  final String deviceId;

  const LandlordFaceVerificationScreen({
    super.key,
    required this.userData,
    required this.contractPdfBytes,
    required this.idDocumentBytes,
    required this.idDocumentName,
    required this.deviceId,
  });

  @override
  State<LandlordFaceVerificationScreen> createState() =>
      _LandlordFaceVerificationScreenState();
}

class _LandlordFaceVerificationScreenState
    extends State<LandlordFaceVerificationScreen>
    with SingleTickerProviderStateMixin {
  CameraController? _cameraController;
  late AudioPlayer _audioPlayer;

  bool _hasAgreedToDisclaimer = false;
  bool _isVerifyingLiveness = false;
  bool _isVerifyingBackend = false;

  bool _enableLivenessCheck = false;

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

    _audioPlayer = AudioPlayer();
    _initializeCamera();
  }

  Future<void> playSound(bool isSuccess) async {
    try {
      String fileName = isSuccess ? 'success.mp3' : 'denied.mp3';
      await _audioPlayer.play(AssetSource(fileName));
    } catch (e) {
      print("Audio Error: $e");
    }
  }

  void _showMessage(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _initializeCamera() async {
    if (!kIsWeb) {
      var status = await Permission.camera.status;
      if (!status.isGranted) await Permission.camera.request();
    }
    try {
      final cameras = await availableCameras();
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
      if (mounted) {
        setState(() {
          _isCameraInitialized = false;
          _processStatus = "Camera Error";
        });
      }
    }
  }

  Future<void> _startLivenessCapture() async {
    await _cameraController?.dispose();
    _cameraController = null;

    setState(() {
      _isCameraInitialized = false;
      _isVerifyingLiveness = true;
      _processStatus = 'Follow on-screen instructions...';
    });
  }

  Future<void> _captureWebAndVerify() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized)
      return;

    setState(() {
      _isVerifyingBackend = true;
      _processStatus = 'Scanning Image...';
    });

    try {
      final XFile capturedFile = await _cameraController!.takePicture();
      if (mounted) await _cameraController?.pausePreview();

      final Uint8List capturedBytes = await capturedFile.readAsBytes();
      await _processBackendUpload(capturedBytes);
    } catch (e) {
      _handleFailure(reason: "Web Camera Capture Error: $e");
    }
  }

  Future<void> _processBackendUpload(Uint8List capturedBytes) async {
    setState(() {
      _processStatus = "Verifying biometrics & securing documents...";
    });

    try {
      User? user = FirebaseAuth.instance.currentUser;
      String? token = await user?.getIdToken();

      var request = http.MultipartRequest(
        'POST',
        Uri.parse(
          '${ApiClass().getApiBaseUrl()}/verify-landlord-identity-app/',
        ),
      );

      request.headers['Authorization'] = 'Bearer $token';
      request.fields['device_id'] = widget.deviceId;

      // Ensure we send the generated PDF correctly
      request.files.add(
        http.MultipartFile.fromBytes(
          'contract_file',
          widget.contractPdfBytes,
          filename: 'legally_binding_contract.pdf',
        ),
      );

      request.files.add(
        http.MultipartFile.fromBytes(
          'id_document',
          widget.idDocumentBytes,
          filename: widget.idDocumentName,
        ),
      );

      request.files.add(
        http.MultipartFile.fromBytes(
          'live_face',
          capturedBytes,
          filename: 'live_face.jpg',
        ),
      );

      var response = await request.send();
      var responseData = await response.stream.bytesToString();

      if (!mounted) return;

      if (response.statusCode == 200) {
        await playSound(true);

        final prefs = await SharedPreferences.getInstance();
        final userDataString = prefs.getString('user_data');
        if (userDataString != null) {
          Map<String, dynamic> localUserData = jsonDecode(userDataString);
          localUserData['is_verified'] = true;
          localUserData['digital_verification_status'] = true;
          await prefs.setString('user_data', jsonEncode(localUserData));
        }

        _showMessage("Digital verification successful! Welcome.", Colors.green);

        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;

        Navigator.pop(context, true);
      } else if (response.statusCode == 403) {
        await playSound(false);
        setState(() {
          _isVerifyingLiveness = false;
          _isVerifyingBackend = false;
          _processStatus = "Verification Failed";
        });
        _showRetryOrManualDialog();
      } else {
        final error =
            jsonDecode(responseData)['error'] ?? "Verification failed.";
        _handleFailure(reason: error);
      }
    } catch (e) {
      _handleFailure(reason: "Secure Upload Error: $e");
    }
  }

  void _showRetryOrManualDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "Verification Failed",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        content: Text(
          "Your live capture did not match the provided ID document. This could be due to poor lighting or blurriness.\n\nWould you like to try again online or submit your profile for manual review by an administrator?",
          style: GoogleFonts.poppins(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _initializeCamera();
            },
            child: Text(
              "Retry",
              style: GoogleFonts.poppins(
                  color: Colors.blue, fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () {
              Navigator.pop(context);
              _requestManualReview();
            },
            child: Text(
              "Manual Review",
              style: GoogleFonts.poppins(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _requestManualReview() async {
    setState(() {
      _isVerifyingBackend = true;
      _processStatus = "Submitting for manual review...";
    });

    try {
      User? user = FirebaseAuth.instance.currentUser;
      String? token = await user?.getIdToken();

      var response = await http.post(
        Uri.parse('${ApiClass().getApiBaseUrl()}/request-manual-review/'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        _showMessage("Profile submitted for manual review.", Colors.orange);

        final prefs = await SharedPreferences.getInstance();
        final userDataString = prefs.getString('user_data');
        if (userDataString != null) {
          Map<String, dynamic> localUserData = jsonDecode(userDataString);
          localUserData['manual_verification_status'] = true;
          await prefs.setString('user_data', jsonEncode(localUserData));
        }

        if (!mounted) return;
        Navigator.pop(context, true);
      } else {
        _handleFailure(reason: "Failed to request manual review. Please try again.");
      }
    } catch (e) {
      _handleFailure(reason: "Error: $e");
    }
  }

  void _handleFailure({String reason = "Verification Failed"}) async {
    if (!mounted) return;
    await playSound(false);

    setState(() {
      _isVerifyingLiveness = false;
      _isVerifyingBackend = false;
      _processStatus = "Ready";
    });

    _showMessage(reason, Colors.red);
    _initializeCamera();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  Widget _glassContainer({required Widget child, EdgeInsetsGeometry? padding}) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: padding ?? const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor.withOpacity(0.7),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: theme.colorScheme.primary.withOpacity(0.4),
              width: 0.7,
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final textColor = theme.colorScheme.onSurface;
    final hintColor = theme.colorScheme.onSecondary;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: textColor),
        title: Text(
          'Live Verification',
          style: GoogleFonts.poppins(
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Stack(
        children: [
          const BubbleBackground(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    children: [
                      if (kDebugMode)
                        _buildDebugToggle(textColor, primaryColor),
                      _buildDetailsPanel(textColor, hintColor),
                      const SizedBox(height: 32),
                      if (!_hasAgreedToDisclaimer)
                        _buildDisclaimerPanel(textColor, primaryColor)
                      else if (_isVerifyingBackend)
                        _buildProcessingPanel(textColor, primaryColor)
                      else
                        _buildLiveCamPanel(textColor, primaryColor, theme),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDebugToggle(Color textColor, Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: _glassContainer(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.bug_report, color: Colors.orange, size: 20),
                const SizedBox(width: 10),
                Text(
                  "DEBUG: Liveness Check",
                  style: GoogleFonts.poppins(
                    color: textColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Switch(
              value: _enableLivenessCheck,
              activeColor: primaryColor,
              onChanged: (val) {
                setState(() {
                  _enableLivenessCheck = val;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsPanel(Color textColor, Color hintColor) {
    final String fullName =
        "${widget.userData['name'] ?? ''} ${widget.userData['surname'] ?? ''}"
            .trim();

    return _glassContainer(
      child: Row(
        children: [
          Container(
            height: 60,
            width: 60,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
              ),
            ),
            child: Icon(
              Icons.person,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullName,
                  style: GoogleFonts.poppins(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  "Comparing against uploaded ID Document",
                  style: GoogleFonts.poppins(color: hintColor, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimerPanel(Color textColor, Color primaryColor) {
    return _glassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.privacy_tip, color: primaryColor, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Biometric Notice",
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            "Your live capture will be transmitted securely and verified against your ID. This ensures platform integrity.",
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: textColor.withOpacity(0.8),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () => setState(() => _hasAgreedToDisclaimer = true),
              child: Text(
                'I AGREE & CONTINUE',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveCamPanel(
    Color textColor,
    Color primaryColor,
    ThemeData theme,
  ) {
    return _glassContainer(
      child: Column(
        children: [
          Text(
            _isVerifyingLiveness
                ? 'Follow instructions within the frame.'
                : (_isCameraInitialized
                      ? 'Align your face within the frame.'
                      : 'Initializing...'),
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: textColor.withOpacity(0.8),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 32),
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 240,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primaryColor.withOpacity(0.1),
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
                              _isVerifyingBackend = true;
                              _processStatus =
                                  'Capturing secure facial biometric...';
                            });

                            try {
                              await Future.delayed(
                                const Duration(milliseconds: 500),
                              );

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

                              await Future.delayed(
                                const Duration(milliseconds: 500),
                              );

                              final XFile capturedFile =
                                  await _cameraController!.takePicture();
                              Uint8List capturedBytes = await capturedFile
                                  .readAsBytes();

                              await _cameraController?.pausePreview();

                              setState(() {
                                _processStatus =
                                    'Verifying biometrics & securing documents...';
                              });

                              await _processBackendUpload(capturedBytes);
                            } catch (e) {
                              _handleFailure(
                                reason:
                                    "Failed to capture final biometric image: $e",
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
                                aspectRatio:
                                    _cameraController!.value.aspectRatio,
                                child: CameraPreview(_cameraController!),
                              )
                            : Center(
                                child: CircularProgressIndicator(
                                  color: primaryColor,
                                ),
                              )),
                ),
              ),
              if (_isCameraInitialized || _isVerifyingLiveness)
                Positioned.fill(
                  child: ClipOval(
                    child: AnimatedBuilder(
                      animation: _scannerController,
                      builder: (context, child) => Align(
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
                                primaryColor.withOpacity(0.8),
                                Colors.transparent,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: primaryColor,
                                blurRadius: 15,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned.fill(
                child: Container(
                  width: 220,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: primaryColor.withOpacity(0.5),
                      width: 4,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
          if (!_isVerifyingLiveness)
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: (kIsWeb || !_enableLivenessCheck)
                    ? _captureWebAndVerify
                    : _startLivenessCapture,
                child: Text(
                  'START FACE MATCH',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProcessingPanel(Color textColor, Color primaryColor) {
    return _glassContainer(
      child: Center(
        child: Column(
          children: [
            const SizedBox(height: 20),
            Icon(Icons.fingerprint_outlined, size: 60, color: primaryColor),
            const SizedBox(height: 40),
            Text(
              "Finalizing Setup",
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
              style: GoogleFonts.poppins(
                color: Theme.of(context).colorScheme.onSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: 150,
              child: LinearProgressIndicator(
                backgroundColor: primaryColor.withOpacity(0.2),
                color: primaryColor,
                minHeight: 4,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}