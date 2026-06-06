import 'dart:convert';
import 'dart:io' show Platform, File;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mobile_app/components/api_class.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart'; // NEW IMPORT
 
class VerifyPermitTab extends StatefulWidget {
  const VerifyPermitTab({super.key});

  @override
  State<VerifyPermitTab> createState() => _VerifyPermitTabState();
}

class _VerifyPermitTabState extends State<VerifyPermitTab> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _isProcessing = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  // --- STEP 1: SCAN QR CODE ---
  Future<void> _verifyQRCode(String qrData) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    _scannerController.stop();

    try {
      final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
      final response = await http.post(
        Uri.parse('${ApiClass().getApiBaseUrl()}/verify-permit-qr/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({'qr_reference': qrData}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _showStagingSheet(data); // Show read-only data & prompt face scan
      } else {
        _showErrorSheet("Invalid or Expired QR Code");
      }
    } catch (e) {
      _showErrorSheet("Network Error. Please try again.");
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  // --- STEP 2: LIVE FACE SCAN & BIOMETRIC MATCH ---
  Future<void> _captureAndMatchFace(String permitId) async {
    try {
      // 1. Open the front camera
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 80,
      );

      if (image == null) return; // User canceled camera

      // 2. Show loading state
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // 3. Send photo to Django for biometric comparison
      final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiClass().getApiBaseUrl()}/verify-face-match/'),
      );

      request.headers['Authorization'] = 'Bearer $idToken';
      request.fields['permit_id'] = permitId;
      request.files.add(
        await http.MultipartFile.fromPath('live_face', image.path),
      );

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (!mounted) return;
      Navigator.pop(context); // Remove loading dialog
      Navigator.pop(context); // Remove the staging sheet

      if (response.statusCode == 200) {
        // FACE MATCHED!
        _showFinalClearanceSheet();
      } else {
        // FACE FAILED TO MATCH
        final errorData = jsonDecode(response.body);
        _showErrorSheet(
          errorData['error'] ?? "Biometric mismatch. Access Denied.",
        );
      }
    } catch (e) {
      Navigator.pop(context);
      _showErrorSheet("Face verification failed due to network error.");
    }
  }

  // --- UI CONTROLLERS ---

  void _showStagingSheet(Map<String, dynamic> data) {
    final bool isApproved = data['status'] == 'APPROVED';
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "QR VERIFIED",
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 16),

              // READ-ONLY TEXT FIELDS
              _buildReadOnlyField(
                "Permit Status",
                data['status'],
                isApproved ? Colors.green : Colors.redAccent,
              ),
              const SizedBox(height: 12),
              _buildReadOnlyField(
                "Student Name",
                "${data['student_name']} (${data['student_number']})",
                theme.colorScheme.onSurface,
              ),
              const SizedBox(height: 12),
              _buildReadOnlyField(
                "Database Face URL",
                data['face_url'] ?? "No image on file",
                theme.colorScheme.onSecondary,
              ),

              const SizedBox(height: 24),

              if (isApproved && data['face_url'] != null)
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        _captureAndMatchFace(data['id'].toString()),
                    icon: const Icon(
                      CupertinoIcons.camera_viewfinder,
                      color: Colors.white,
                    ),
                    label: const Text(
                      "LAUNCH LIVE FACE SCANNER",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),

              if (!isApproved)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    "Cannot proceed to face scan. This permit is not approved.",
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),

              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _scannerController.start();
                  },
                  child: Text(
                    "CANCEL",
                    style: TextStyle(
                      color: theme.colorScheme.onSecondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: textColor,
              fontSize: 13,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  void _showFinalClearanceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      builder: (context) => Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                CupertinoIcons.check_mark_circled_solid,
                color: Colors.green,
                size: 80,
              ),
              const SizedBox(height: 16),
              Text(
                "BIOMETRICS MATCHED",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Identity verified. Student is cleared to exit the premises.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _scannerController.start();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    "CLOSE GATE",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showErrorSheet(String error) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      builder: (context) => Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                CupertinoIcons.exclamationmark_triangle_fill,
                color: Colors.redAccent,
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                "VERIFICATION FAILED",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _scannerController.start();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    "TRY AGAIN",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
                _verifyQRCode(barcodes.first.rawValue!);
              }
            },
          ),
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.6)),
            child: SafeArea(
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Text(
                      "SCAN PERMIT QR",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      border: Border.all(color: primary, width: 4),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: _isProcessing
                        ? Center(
                            child: CircularProgressIndicator(color: primary),
                          )
                        : null,
                  ),
                  const Spacer(),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 120.0),
                    child: Text(
                      "Align QR Code within the frame",
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
