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
      final response = await http.post(
        Uri.parse('${ApiClass().getApiBaseUrl()}/verify-gate-pass-qr/'),
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
        _showErrorSheet("Failed to verify gate pass.");
      }
    } catch (e) {
      _showErrorSheet("Network Error. Please try again.");
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  // --- UI CONTROLLERS ---

  void _showStagingSheet(Map<String, dynamic> data) {
    final bool isActive = data['status'] == 'ACTIVE';
    final theme = Theme.of(context);
    
    // Split the bundled items for clean display
    final List<String> assetNames = (data['asset_name'] ?? 'Unknown Asset').split(' + ');
    final List<String> assetNums = (data['asset_number'] ?? 'N/A').split(' + ');
    
    final DateTime expiryDate = DateTime.parse(data['expires_at']).toLocal();

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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "ASSET PASS VERIFIED",
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.0,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isActive ? Colors.green.withOpacity(0.1) : Colors.redAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isActive ? "ACTIVE" : "EXPIRED",
                      style: TextStyle(
                        color: isActive ? Colors.green : Colors.redAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              _buildReadOnlyField(
                "Student Name",
                "${data['student_name']} (${data['student_number']})",
                theme.colorScheme.onSurface,
              ),
              const SizedBox(height: 12),
              _buildReadOnlyField(
                "Expiry Date",
                DateFormat('MMM dd, yyyy - HH:mm').format(expiryDate),
                isActive ? theme.colorScheme.onSurface : Colors.redAccent,
              ),

              const SizedBox(height: 24),
              Text(
                "REGISTERED ASSETS IN THIS BUNDLE",
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSecondary,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              
              // Display the split bundle items
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.colorScheme.onSurface.withOpacity(0.1)),
                ),
                child: Column(
                  children: List.generate(assetNames.length, (i) {
                    final sn = i < assetNums.length ? assetNums[i] : 'N/A';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(CupertinoIcons.device_laptop, size: 16, color: theme.colorScheme.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(assetNames[i], style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 14)),
                                if (sn != 'N/A')
                                  Text("SN: $sn", style: TextStyle(color: theme.colorScheme.onSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),

              const SizedBox(height: 24),

              if (isActive)
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _scannerController.start();
                    },
                    icon: const Icon(
                      CupertinoIcons.checkmark_shield_fill,
                      color: Colors.white,
                    ),
                    label: const Text(
                      "ALLOW ASSETS THROUGH",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),

              if (!isActive)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    children: [
                      Icon(CupertinoIcons.exclamationmark_triangle_fill, color: Colors.redAccent, size: 24),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "This gate pass has expired. The student must renew it in their app before leaving with these assets.",
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
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
                    "DISMISS & SCAN ANOTHER",
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
                      "SCAN ASSET PASS QR",
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
                      "Align Asset QR Code within the frame",
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