import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mobile_app/components/api_class.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class VerifyGatePassTab extends StatefulWidget {
  const VerifyGatePassTab({super.key});

  @override
  State<VerifyGatePassTab> createState() => _VerifyGatePassTabState();
}

class _VerifyGatePassTabState extends State<VerifyGatePassTab> {
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

      // Hit the correct Permit Verification Endpoint
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
        _showStagingSheet(data);
      } else if (response.statusCode == 404) {
        _showErrorSheet("Invalid or Fake QR Code Detected.");
      } else {
        _showErrorSheet("Failed to verify permit.");
      }
    } catch (e) {
      _showErrorSheet("Network Error. Please try again.");
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  // --- UI CONTROLLERS ---

  void _showStagingSheet(Map<String, dynamic> data) {
    final bool isApproved = data['status'] == 'APPROVED';
    final theme = Theme.of(context);

    // Parse the date if it exists
    String formattedDate = "N/A";
    if (data['departure_date'] != null) {
      final DateTime date = DateTime.parse(data['departure_date']).toLocal();
      formattedDate = DateFormat('MMM dd, yyyy - HH:mm').format(date);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      builder: (context) => Container(
        height:
            MediaQuery.of(context).size.height *
            0.9, // Make it tall like the screenshot
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(
            0xFFF4F6FB,
          ), // Light bluish-grey background from screenshot
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top Drag Handle & Close Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(
                      CupertinoIcons.back,
                      color: Color(0xFF1B235A),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      _scannerController.start();
                    },
                  ),
                  const Text(
                    "Permit Details",
                    style: TextStyle(
                      color: Color(0xFF1B235A),
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 48), // Balance for centering
                ],
              ),

              const SizedBox(height: 16),

              // Avatar
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.blue.withOpacity(0.2),
                    width: 3,
                  ),
                ),
                child: const Icon(
                  CupertinoIcons.person_fill,
                  size: 50,
                  color: Color(0xFF1B235A),
                ),
              ),

              const SizedBox(height: 16),

              // Name & ID
              Text(
                data['student_name'] ?? "Unknown Student",
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1B235A),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                "ID: ${data['student_number'] ?? 'N/A'}",
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                  letterSpacing: 1.0,
                ),
              ),

              const SizedBox(height: 16),

              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isApproved
                      ? Colors.green.withOpacity(0.15)
                      : Colors.redAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isApproved
                        ? Colors.green.withOpacity(0.3)
                        : Colors.redAccent.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isApproved
                          ? CupertinoIcons.check_mark_circled_solid
                          : CupertinoIcons.xmark_circle_fill,
                      color: isApproved ? Colors.green : Colors.redAccent,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      data['status'] ?? "UNKNOWN",
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

              const SizedBox(height: 24),

              // Details Card
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildDetailRow(
                          CupertinoIcons.map_pin_ellipse,
                          "DESTINATION PROVINCE",
                          data['destination_province'] ?? 'N/A',
                        ),
                        const Divider(height: 24, color: Color(0xFFF0F2F5)),

                        _buildDetailRow(
                          CupertinoIcons.house_fill,
                          "FULL ADDRESS",
                          data['destination_address'] ?? 'N/A',
                        ),
                        const Divider(height: 24, color: Color(0xFFF0F2F5)),

                        _buildDetailRow(
                          CupertinoIcons.calendar,
                          "DEPARTURE DATE",
                          formattedDate,
                        ),
                        const Divider(height: 24, color: Color(0xFFF0F2F5)),

                        _buildDetailRow(
                          CupertinoIcons.text_alignleft,
                          "REASON FOR LEAVE",
                          data['reason'] ?? 'N/A',
                        ),
                        const Divider(height: 24, color: Color(0xFFF0F2F5)),

                        _buildDetailRow(
                          CupertinoIcons.phone_fill,
                          "PARENT/GUARDIAN CELL",
                          data['parent_cell_number'] ?? 'N/A',
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Bottom Button
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // TODO: Navigate to Live Face Scanner
                    Navigator.pop(context);
                    _scannerController.start();
                  },
                  icon: const Icon(
                    CupertinoIcons.viewfinder,
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
                    backgroundColor: const Color(0xFF1B235A),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: const Color(0xFF1B235A).withOpacity(0.5)),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: Colors.grey,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1B235A),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
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
