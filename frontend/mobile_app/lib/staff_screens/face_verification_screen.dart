import 'dart:convert';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mobile_app/components/api_class.dart';

class FaceVerificationScreen extends StatefulWidget {
  final String reportId;
  final String studentId;

  const FaceVerificationScreen({
    super.key,
    required this.reportId,
    required this.studentId,
  });

  @override
  State<FaceVerificationScreen> createState() => _FaceVerificationScreenState();
}

class _FaceVerificationScreenState extends State<FaceVerificationScreen> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        // Default to back camera for staff scanning a patient, or fallback to front
        CameraDescription selectedCamera = _cameras!.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.back,
          orElse: () => _cameras!.first,
        );

        _cameraController = CameraController(
          selectedCamera,
          ResolutionPreset.high,
          enableAudio: false,
        );

        await _cameraController!.initialize();
        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
          });
        }
      } else {
        _showSnackBar("No cameras available on this device.", Colors.redAccent);
      }
    } catch (e) {
      _showSnackBar("Failed to open hardware camera: $e", Colors.redAccent);
    }
  }

  Future<void> _captureAndVerify() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized || _isProcessing) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // 1. Capture the image frame
      final XFile imageFile = await _cameraController!.takePicture();
      
      // 2. Fetch Firebase Token
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("Session expired. Authenticate again.");
      final idToken = await user.getIdToken();

      // 3. Construct 1:1 Multipart verification payload
      final uri = Uri.parse('${ApiClass().getApiBaseUrl()}/emergencies/unlock-medical-data/');
      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $idToken'
        ..fields['report_id'] = widget.reportId
        ..fields['target_student_id'] = widget.studentId
        ..files.add(await http.MultipartFile.fromPath('face_image', imageFile.path));

      // 4. Dispatch payload to Django backend
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (!mounted) return;

      if (response.statusCode == 200) {
        final Map<String, dynamic> medicalData = jsonDecode(response.body);
        
        _showSnackBar("Biometric Verification Successful", Colors.green);
        
        // Return back to dashboard carrying the decrypted medical record object
        Navigator.pop(context, medicalData);
      } else {
        final errorResponse = jsonDecode(response.body);
        throw Exception(errorResponse['error'] ?? "Biometric mismatch detected.");
      }
    } catch (e) {
      _showSnackBar(e.toString().replaceAll('Exception: ', ''), Colors.redAccent);
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "BIOMETRIC VERIFICATION",
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Camera Canvas Viewport
          if (_isCameraInitialized && _cameraController != null)
            Center(
              child: AspectRatio(
                aspectRatio: 1 / _cameraController!.value.aspectRatio,
                child: CameraPreview(_cameraController!),
              ),
            )
          else
            const Center(
              child: CircularProgressIndicator(color: Colors.redAccent),
            ),

          // Premium Matte Viewfinder Overlay
          Positioned.fill(
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(
                Colors.black.withOpacity(0.6),
                BlendMode.srcOut,
              ),
              child: Stack(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.transparent,
                      backgroundBlendMode: BlendMode.dstOut,
                    ),
                  ),
                  Align(
                    alignment: Alignment.center,
                    child: Container(
                      height: 280,
                      width: 280,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(40),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Viewfinder Frame Borders
          Align(
            alignment: Alignment.center,
            child: Container(
              height: 280,
              width: 280,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white.withOpacity(0.8), width: 2),
                borderRadius: BorderRadius.circular(40),
              ),
            ),
          ),

          // Control Panel Overlay
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Text(
                  _isProcessing ? "Analyzing Facial Embeddings..." : "Align patient face within the frame",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: _captureAndVerify,
                  child: Container(
                    height: 84,
                    width: 84,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                    ),
                    padding: const EdgeInsets.all(6),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _isProcessing ? Colors.grey : Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                      child: _isProcessing
                          ? const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3,
                              ),
                            )
                          : const Icon(
                              CupertinoIcons.camera_fill,
                              color: Colors.white,
                              size: 28,
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}