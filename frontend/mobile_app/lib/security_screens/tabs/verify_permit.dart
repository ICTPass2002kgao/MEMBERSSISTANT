import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mobile_app/components/api_class.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

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

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  // --- SCAN QR CODE ---
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
        
        if (!mounted) return;
        // Navigate to the new full-page details screen
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PermitDetailsScreen(permitData: data),
          ),
        );
        
        // Restart the scanner when returning from the details page
        if (mounted) {
          _scannerController.start();
        }

      } else {
        _showErrorSheet("Invalid or Expired QR Code");
      }
    } catch (e) {
      _showErrorSheet("Network Error. Please try again.");
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
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

// --- NEW FULL PAGE FOR PERMIT DETAILS & FACE SCAN ---

class PermitDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> permitData;

  const PermitDetailsScreen({super.key, required this.permitData});

  @override
  State<PermitDetailsScreen> createState() => _PermitDetailsScreenState();
}

class _PermitDetailsScreenState extends State<PermitDetailsScreen> {
  final ImagePicker _picker = ImagePicker();

  Future<void> _captureAndMatchFace(String permitId) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 80,
      );

      if (image == null) return;

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

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

      if (response.statusCode == 200) {
        _showFinalClearanceSheet();
      } else {
        final errorData = jsonDecode(response.body);
        _showMatchErrorSheet(
          errorData['error'] ?? "Biometric mismatch. Access Denied.",
        );
      }
    } catch (e) {
      Navigator.pop(context);
      _showMatchErrorSheet("Face verification failed due to network error.");
    }
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
                    // Pop the success sheet, then pop the details screen to go back to scanner
                    Navigator.pop(context);
                    Navigator.pop(context); 
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    "CLOSE & RETURN",
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

  void _showMatchErrorSheet(String error) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
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
                "MATCH FAILED",
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
                  onPressed: () => Navigator.pop(context),
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

  String _formatDate(String? isoString) {
    if (isoString == null || isoString.isEmpty) return "N/A";
    try {
      final date = DateTime.parse(isoString).toLocal();
      return DateFormat('MMM dd, yyyy - HH:mm').format(date);
    } catch (e) {
      return "Invalid Date";
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.permitData;
    final bool isApproved = data['status'] == 'APPROVED';
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final slateColor = theme.colorScheme.onSecondary;
    final textColor = theme.colorScheme.onSurface;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(CupertinoIcons.back, color: primaryColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Permit Details",
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // --- STUDENT PROFILE PICTURE ---
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: primaryColor.withOpacity(0.3),
                    width: 3,
                  ),
                ),
                child: ClipOval(
                  child: data['face_url'] != null && data['face_url'].toString().isNotEmpty
                      ? Image.network(
                          data['face_url'],
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Icon(CupertinoIcons.person_solid, size: 60, color: primaryColor),
                        )
                      : Icon(CupertinoIcons.person_solid, size: 60, color: primaryColor),
                ),
              ),
              const SizedBox(height: 16),
              
              Text(
                data['student_name'] ?? 'Unknown Student',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "ID: ${data['student_number'] ?? 'N/A'}",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: slateColor,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 16),

              // --- STATUS BADGE ---
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isApproved ? Colors.green.withOpacity(0.15) : Colors.redAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isApproved ? Colors.green.withOpacity(0.3) : Colors.redAccent.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isApproved ? CupertinoIcons.check_mark_circled_solid : CupertinoIcons.xmark_circle_fill,
                      color: isApproved ? Colors.green : Colors.redAccent,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      data['status'] ?? 'UNKNOWN',
                      style: TextStyle(
                        color: isApproved ? Colors.green : Colors.redAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // --- PERMIT DETAILS CARDS ---
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: primaryColor.withOpacity(0.1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow(
                      CupertinoIcons.map_pin_ellipse,
                      "Destination Province",
                      data['destination'] ?? data['destination_province'] ?? 'N/A', // Checked both based on API variants
                      primaryColor,
                      textColor,
                      slateColor,
                    ),
                    const Divider(height: 24, thickness: 1),
                    _buildDetailRow(
                      CupertinoIcons.house_fill,
                      "Full Address",
                      data['destination_address'] ?? 'N/A',
                      primaryColor,
                      textColor,
                      slateColor,
                    ),
                    const Divider(height: 24, thickness: 1),
                    _buildDetailRow(
                      CupertinoIcons.calendar,
                      "Departure Date",
                      _formatDate(data['departure_date']),
                      primaryColor,
                      textColor,
                      slateColor,
                    ),
                    const Divider(height: 24, thickness: 1),
                    _buildDetailRow(
                      CupertinoIcons.text_alignleft,
                      "Reason for Leave",
                      data['reason'] ?? 'N/A',
                      primaryColor,
                      textColor,
                      slateColor,
                    ),
                    const Divider(height: 24, thickness: 1),
                    _buildDetailRow(
                      CupertinoIcons.phone_fill,
                      "Parent/Guardian Cell",
                      data['parent_cell_number'] ?? 'N/A',
                      primaryColor,
                      textColor,
                      slateColor,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // --- ACTIONS ---
              if (isApproved && data['face_url'] != null)
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton.icon(
                    onPressed: () => _captureAndMatchFace(data['id'].toString()),
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
                      backgroundColor: primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                )
              else if (!isApproved)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    "Access Denied. This permit is not approved for exit.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    "Missing database face profile. Cannot verify biometrics.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, Color primary, Color textCol, Color slate) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: primary.withOpacity(0.7)),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  color: slate,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  color: textCol,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}