import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:mobile_app/components/api_class.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class SecurityVisitorScanner extends StatefulWidget {
  const SecurityVisitorScanner({super.key});

  @override
  State<SecurityVisitorScanner> createState() => _SecurityVisitorScannerState();
}

class _SecurityVisitorScannerState extends State<SecurityVisitorScanner> {
  Map<String, dynamic>? _scannedVisitor;
  bool _isScanning = false;
  bool _isLoading = false;

  // Radio Button State: 'VERIFY', 'SIGN_IN', 'SIGN_OUT'
  String _selectedAction = 'VERIFY';

  Future<void> _processScan(String qrReference) async {
    setState(() {
      _isScanning = false;
      _isLoading = true;
    });

    try {
      final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
      final response = await http.post(
        Uri.parse('${ApiClass().getApiBaseUrl()}/scan-visitor-qr/'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "qr_reference": qrReference,
          "action": _selectedAction,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        setState(() => _scannedVisitor = data['visitor']);
        _showSnackBar(data['message'], isError: false);
      } else {
        _showSnackBar(data['error'] ?? "Action rejected by system.");
      }
    } catch (e) {
      _showSnackBar("Network Error occurred.");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
      ),
    );
  }

  Uint8List? _getSignatureBytes(String? base64String) {
    if (base64String == null || !base64String.contains(',')) return null;
    return base64Decode(base64String.split(',').last);
  }

  String _formatTime(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return "--:--";
    final date = DateTime.parse(isoDate).toLocal();
    return DateFormat('HH:mm').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final slateColor = theme.colorScheme.onSecondary;
    final textColor = theme.colorScheme.onSurface;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "SECURITY DASHBOARD",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: primaryColor,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Visitor Checkpoint",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: textColor,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Premium Segmented Control (Radio Buttons)
                  Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: primaryColor.withOpacity(0.1)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildActionTab(
                            "Verify",
                            "VERIFY",
                            CupertinoIcons.search,
                            primaryColor,
                            slateColor,
                          ),
                        ),
                        Expanded(
                          child: _buildActionTab(
                            "Sign In",
                            "SIGN_IN",
                            CupertinoIcons.arrow_right_to_line,
                            primaryColor,
                            slateColor,
                          ),
                        ),
                        Expanded(
                          child: _buildActionTab(
                            "Sign Out",
                            "SIGN_OUT",
                            CupertinoIcons.arrow_left_to_line,
                            primaryColor,
                            slateColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(color: primaryColor),
                    )
                  : _isScanning
                  ? _buildScannerView(primaryColor)
                  : _scannedVisitor == null
                  ? _buildEmptyState(primaryColor, slateColor, textColor)
                  : _buildResultCard(primaryColor, slateColor, textColor),
            ),

            // Updated bottom padding to clear the custom navigation bar
            Padding(
              padding: const EdgeInsets.only(
                left: 24,
                right: 24,
                bottom: 120,
                top: 16,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton.icon(
                  onPressed: () => setState(() {
                    _isScanning = true;
                    _scannedVisitor = null;
                  }),
                  icon: const Icon(CupertinoIcons.qrcode_viewfinder),
                  label: const Text(
                    "SCAN QR CODE",
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- UI COMPONENTS ---

  Widget _buildActionTab(
    String text,
    String value,
    IconData icon,
    Color primaryColor,
    Color slateColor,
  ) {
    bool isSelected = _selectedAction == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedAction = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.all(4),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: isSelected ? Colors.white : slateColor),
            const SizedBox(width: 4),
            Text(
              text,
              style: TextStyle(
                color: isSelected ? Colors.white : slateColor,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    Color primaryColor,
    Color slateColor,
    Color textColor,
  ) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.qrcode_viewfinder,
            size: 64,
            color: slateColor.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            "Ready to Scan",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Select an action above, then tap Scan.",
            style: TextStyle(color: slateColor),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerView(Color primaryColor) {
    return Container(
      margin: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: primaryColor.withOpacity(0.2), width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: MobileScanner(
          onDetect: (capture) {
            final List<Barcode> barcodes = capture.barcodes;
            if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
              _processScan(barcodes.first.rawValue!);
            }
          },
        ),
      ),
    );
  }

  Widget _buildResultCard(
    Color primaryColor,
    Color slateColor,
    Color textColor,
  ) {
    final v = _scannedVisitor!;
    final signatureBytes = _getSignatureBytes(v['visitor_signature']);
    final status = v['status'];

    Color statusColor = Colors.orange;
    if (status == 'SIGNED_IN') statusColor = Colors.green;
    if (status == 'SIGNED_OUT') statusColor = slateColor;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: primaryColor.withOpacity(0.03),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: primaryColor.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Compact Status Tab
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "VISITOR DETAILS",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: slateColor,
                    letterSpacing: 1.0,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        status == 'SIGNED_OUT'
                            ? CupertinoIcons.check_mark_circled_solid
                            : CupertinoIcons.time,
                        color: statusColor,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        status.replaceAll('_', ' '),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            _detailRow("Name", v['visitor_name'], textColor, slateColor),
            _detailRow(
              "ID / Student No",
              v['visitor_id_number'],
              textColor,
              slateColor,
            ),
            _detailRow("Contact", v['visitor_contact'], textColor, slateColor),

            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(),
            ),

            Text(
              "HOST DETAILS",
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: slateColor,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 12),
            _detailRow(
              "Student",
              "${v['student_name']} ${v['student_surname']}",
              textColor,
              slateColor,
            ),
            _detailRow(
              "Location",
              "Block ${v['block_name']} - Room ${v['room_number']}",
              textColor,
              slateColor,
            ),

            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(),
            ),

            // Time Tracking
            Row(
              children: [
                Expanded(
                  child: _timeBox(
                    "TIME IN",
                    _formatTime(v['time_in']),
                    primaryColor,
                    textColor,
                    slateColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _timeBox(
                    "TIME OUT",
                    _formatTime(v['time_out']),
                    primaryColor,
                    textColor,
                    slateColor,
                  ),
                ),
              ],
            ),

            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(),
            ),

            Text(
              "VISITOR SIGNATURE",
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: slateColor,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 12),
            if (signatureBytes != null)
              Container(
                height: 100,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: primaryColor.withOpacity(0.1)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.memory(signatureBytes, fit: BoxFit.contain),
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  "No Signature Found.",
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(
    String title,
    String value,
    Color textColor,
    Color slateColor,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              title,
              style: TextStyle(
                color: slateColor,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeBox(
    String label,
    String time,
    Color primaryColor,
    Color textColor,
    Color slateColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              color: slateColor,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            time,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
