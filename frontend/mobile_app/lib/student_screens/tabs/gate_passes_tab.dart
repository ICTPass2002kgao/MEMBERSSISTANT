import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:mobile_app/components/api_class.dart';
import 'package:qr_flutter/qr_flutter.dart';

class GatePassesTab extends StatefulWidget {
  const GatePassesTab({super.key});

  @override
  State<GatePassesTab> createState() => _GatePassesTabState();
}

class _GatePassesTabState extends State<GatePassesTab> {
  bool _isLoading = true;
  bool _isSubmitting = false;
  int _currentViewIndex = 0; // 0 = Register Asset, 1 = My Gate Passes

  List<dynamic> _myGatePasses = [];

  // Dynamic Form Controllers for multiple items
  final List<Map<String, TextEditingController>> _assetItems = [
    {'name': TextEditingController(), 'number': TextEditingController()},
  ];

  final int _maxItems =
      4; // Prevent adding too many items to avoid database string limits

  @override
  void initState() {
    super.initState();
    _fetchGatePasses();
  }

  @override
  void dispose() {
    for (var item in _assetItems) {
      item['name']?.dispose();
      item['number']?.dispose();
    }
    super.dispose();
  }

  void _addAssetField() {
    if (_assetItems.length < _maxItems) {
      setState(() {
        _assetItems.add({
          'name': TextEditingController(),
          'number': TextEditingController(),
        });
      });
    }
  }

  void _removeAssetField(int index) {
    setState(() {
      _assetItems[index]['name']?.dispose();
      _assetItems[index]['number']?.dispose();
      _assetItems.removeAt(index);
    });
  }

  Future<void> _fetchGatePasses() async {
    setState(() => _isLoading = true);
    try {
      final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
      final response = await http.get(
        Uri.parse('${ApiClass().getApiBaseUrl()}/gate-passes/'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _myGatePasses = data is List ? data : (data['results'] ?? []);
            _myGatePasses.sort(
              (a, b) => (b['issued_at'] ?? '').compareTo(a['issued_at'] ?? ''),
            );
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitGatePass() async {
    // 1. Validate and gather data
    List<String> names = [];
    List<String> numbers = [];

    for (var item in _assetItems) {
      final nameStr = item['name']!.text.trim();
      final numStr = item['number']!.text.trim();

      if (nameStr.isNotEmpty) {
        names.add(nameStr);
        numbers.add(
          numStr.isEmpty ? 'N/A' : numStr,
        ); // Default to N/A if no serial is provided for an accessory
      }
    }

    if (names.isEmpty) {
      _showSnackBar("Please provide details for at least one asset.");
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();

      // Bundle them into single strings joined by " + "
      final payload = {
        "asset_name": names.join(' + '),
        "asset_number": numbers.join(' + '),
        "is_active": true,
      };

      final response = await http.post(
        Uri.parse('${ApiClass().getApiBaseUrl()}/gate-passes/'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 201) {
        // Reset form
        setState(() {
          for (var item in _assetItems) {
            item['name']?.dispose();
            item['number']?.dispose();
          }
          _assetItems.clear();
          _assetItems.add({
            'name': TextEditingController(),
            'number': TextEditingController(),
          });
          _currentViewIndex = 1; // Switch to history tab
        });

        await _fetchGatePasses();
        _showSuccessDialog(
          "Bundle Registered!",
          "Your 3-month gate pass for these items has been generated.",
        );
      } else {
        throw Exception("Server rejected the request.");
      }
    } catch (e) {
      _showSnackBar("Failed to register assets. Please try again.");
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _renewGatePass(String passId) async {
    setState(() => _isLoading = true);
    try {
      final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
      final newExpiry = DateTime.now()
          .add(const Duration(days: 90))
          .toUtc()
          .toIso8601String();

      final response = await http.patch(
        Uri.parse('${ApiClass().getApiBaseUrl()}/gate-passes/$passId/'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({"is_active": true, "expires_at": newExpiry}),
      );

      if (response.statusCode == 200) {
        await _fetchGatePasses();
        _showSuccessDialog(
          "Pass Renewed!",
          "Your gate pass is valid for another 3 months.",
        );
      } else {
        throw Exception("Failed to renew.");
      }
    } catch (e) {
      _showSnackBar("Failed to renew gate pass.");
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  void _showSuccessDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Icon(
          CupertinoIcons.checkmark_shield_fill,
          color: Colors.blueAccent,
          size: 64,
        ),
        content: Text(
          "$title\n$message",
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "GOT IT",
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
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
                    "ASSETS & DEVICES",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: primaryColor,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Gate Passes",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: textColor,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 24),

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
                          child: _buildSegmentButton(
                            "Register Assets",
                            0,
                            primaryColor,
                            textColor,
                            slateColor,
                          ),
                        ),
                        Expanded(
                          child: _buildSegmentButton(
                            "My Passes",
                            1,
                            primaryColor,
                            textColor,
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
              child: _currentViewIndex == 0
                  ? _buildRequestForm(primaryColor, slateColor, textColor)
                  : _buildPassesList(primaryColor, slateColor, textColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestForm(
    Color primaryColor,
    Color slateColor,
    Color textColor,
  ) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(
          left: 24,
          right: 24,
          bottom: 120,
          top: 8,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orangeAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.orangeAccent.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(CupertinoIcons.info_circle_fill, color: Colors.orange),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Gate passes are valid for 3 months. You can bundle multiple items (e.g., Laptop + Charger) on a single pass.",
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
            const Text(
              "Item Details",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),

            // Dynamic List of Asset Forms
            ...List.generate(_assetItems.length, (index) {
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: primaryColor.withOpacity(0.1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Item ${index + 1}",
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: primaryColor,
                            fontSize: 12,
                          ),
                        ),
                        if (_assetItems.length > 1)
                          GestureDetector(
                            onTap: () => _removeAssetField(index),
                            child: const Icon(
                              CupertinoIcons.trash_fill,
                              color: Colors.redAccent,
                              size: 18,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildPremiumInput(
                      "Asset Name",
                      "e.g., MacBook Pro",
                      _assetItems[index]['name']!,
                      CupertinoIcons.device_laptop,
                      primaryColor,
                      slateColor,
                      textColor,
                    ),
                    const SizedBox(height: 12),
                    _buildPremiumInput(
                      "Serial Number (Optional)",
                      "e.g., SN: 12345ABC",
                      _assetItems[index]['number']!,
                      CupertinoIcons.barcode,
                      primaryColor,
                      slateColor,
                      textColor,
                    ),
                  ],
                ),
              );
            }),

            // Add Another Item Button
            if (_assetItems.length < _maxItems)
              Center(
                child: TextButton.icon(
                  onPressed: _addAssetField,
                  icon: Icon(
                    CupertinoIcons.add_circled_solid,
                    color: primaryColor,
                  ),
                  label: Text(
                    "ADD ANOTHER ITEM",
                    style: TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitGatePass,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      )
                    : const Text(
                        "GENERATE GATE PASS",
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
    );
  }

  Widget _buildPassesList(
    Color primaryColor,
    Color slateColor,
    Color textColor,
  ) {
    if (_isLoading)
      return Center(child: CircularProgressIndicator(color: primaryColor));

    if (_myGatePasses.isEmpty) {
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
              "No Assets Registered",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Register your devices to generate gate passes.",
              style: TextStyle(color: slateColor),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: primaryColor,
      onRefresh: _fetchGatePasses,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.only(
          left: 24,
          right: 24,
          bottom: 120,
          top: 8,
        ),
        itemCount: _myGatePasses.length,
        itemBuilder: (context, index) {
          final pass = _myGatePasses[index];

          // Split the bundled items back into lists for clean UI display
          final List<String> assetNames =
              (pass['asset_name'] ?? 'Unknown Asset').split(' + ');
          final List<String> assetNums = (pass['asset_number'] ?? 'N/A').split(
            ' + ',
          );

          final String passId = pass['id'].toString();
          final DateTime expiryDate = DateTime.parse(
            pass['expires_at'],
          ).toLocal();
          final bool isExpired =
              DateTime.now().isAfter(expiryDate) || pass['is_active'] == false;

          return Container(
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: isExpired
                  ? Colors.redAccent.withOpacity(0.03)
                  : primaryColor.withOpacity(0.03),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isExpired
                    ? Colors.redAccent.withOpacity(0.2)
                    : primaryColor.withOpacity(0.1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Upper Section: Details
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Registered Bundle",
                              style: TextStyle(
                                color: primaryColor,
                                fontWeight: FontWeight.w900,
                                fontSize: 10,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Map through the bundled items and render them nicely
                            ...List.generate(assetNames.length, (i) {
                              final sn = i < assetNums.length
                                  ? assetNums[i]
                                  : 'N/A';
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "• ",
                                      style: TextStyle(
                                        color: textColor,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            assetNames[i],
                                            style: TextStyle(
                                              color: textColor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          if (sn != 'N/A')
                                            Text(
                                              "SN: $sn",
                                              style: TextStyle(
                                                color: slateColor,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isExpired
                              ? Colors.red.withOpacity(0.1)
                              : Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isExpired
                                ? Colors.red.withOpacity(0.3)
                                : Colors.green.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isExpired
                                  ? CupertinoIcons.xmark_circle_fill
                                  : CupertinoIcons.check_mark_circled_solid,
                              color: isExpired ? Colors.red : Colors.green,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isExpired ? "EXPIRED" : "ACTIVE",
                              style: TextStyle(
                                color: isExpired ? Colors.red : Colors.green,
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
                ),

                // Lower Section: QR Code OR Renew Button
                if (!isExpired) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(24),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          "SECURITY SCAN CODE",
                          style: TextStyle(
                            color: Colors.black.withOpacity(0.5),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.0,
                          ),
                        ),
                        const SizedBox(height: 16),
                        QrImageView(
                          data: passId,
                          version: QrVersions.auto,
                          size: 160.0,
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black87,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Valid until: ${DateFormat('MMM dd, yyyy').format(expiryDate)}",
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.05),
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(24),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          "Expired on ${DateFormat('MMM dd, yyyy').format(expiryDate)}",
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => _renewGatePass(passId),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text(
                              "RENEW FOR 3 MONTHS",
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  // --- UI Helpers ---

  Widget _buildSegmentButton(
    String text,
    int index,
    Color primaryColor,
    Color textColor,
    Color slateColor,
  ) {
    bool isSelected = _currentViewIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentViewIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.all(4),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? primaryColor : slateColor,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(
    Color primaryColor,
    Color slateColor,
    IconData icon,
  ) {
    return InputDecoration(
      prefixIcon: Icon(icon, color: slateColor),
      filled: true,
      fillColor: primaryColor.withOpacity(0.05),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: primaryColor.withOpacity(0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: primaryColor, width: 2),
      ),
    );
  }

  Widget _buildPremiumInput(
    String label,
    String hint,
    TextEditingController controller,
    IconData icon,
    Color primary,
    Color slate,
    Color textCol,
  ) {
    return TextFormField(
      controller: controller,
      style: TextStyle(color: textCol, fontWeight: FontWeight.w600),
      decoration: _inputDecoration(primary, slate, icon).copyWith(
        hintText: hint,
        hintStyle: TextStyle(color: slate.withOpacity(0.5)),
      ),
    );
  }
}
