import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:mobile_app/components/api_class.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:signature/signature.dart';

class PermitsTab extends StatefulWidget {
  const PermitsTab({super.key});

  @override
  State<PermitsTab> createState() => _PermitsTabState();
}

class _PermitsTabState extends State<PermitsTab> {
  bool _isLoading = true;
  bool _isSubmitting = false;
  int _currentViewIndex = 0; // 0 = Request Form, 1 = My Permits, 2 = Visitors

  // --- PERMIT VARIABLES ---
  List<dynamic> _myPermits = [];
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _parentCellController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  String? _selectedProvince;
  DateTime _departureDate = DateTime.now().add(const Duration(hours: 1));

  final List<String> _provinces = [
    'Gauteng',
    'KwaZulu-Natal',
    'Western Cape',
    'Eastern Cape',
    'Free State',
    'Mpumalanga',
    'Limpopo',
    'North West',
    'Northern Cape',
    'Outside SA',
  ];

  // --- VISITOR VARIABLES ---
  List<dynamic> _myVisitors = [];
  Map<String, dynamic>? _studentData;
  bool _showVisitorForm = false;
  final TextEditingController _vNameController = TextEditingController();
  final TextEditingController _vContactController = TextEditingController();
  final TextEditingController _vIdController = TextEditingController();

  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
      final url = ApiClass().getApiBaseUrl();

      // 1. Fetch Permits
      final pRes = await http.get(
        Uri.parse('$url/leave-permits/'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );
      if (pRes.statusCode == 200) {
        final data = jsonDecode(pRes.body);
        _myPermits = data is List ? data : (data['results'] ?? []);
        _myPermits.sort(
          (a, b) => (b['created_at'] ?? '').compareTo(a['created_at'] ?? ''),
        );
      }

      // 2. Fetch Student Info (for Visitor Room auto-fill)
      final sRes = await http.get(
        Uri.parse('$url/students/me/'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );
      if (sRes.statusCode == 200) {
        _studentData = jsonDecode(sRes.body);
      }

      // 3. Fetch Visitors
      final vRes = await http.get(
        Uri.parse('$url/visitor-registers/'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );
      if (vRes.statusCode == 200) {
        final data = jsonDecode(vRes.body);
        _myVisitors = data is List ? data : (data['results'] ?? []);
      }
    } catch (e) {
      debugPrint("Fetch Data Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDateTime() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _departureDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );

    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_departureDate),
      );

      if (pickedTime != null) {
        setState(() {
          _departureDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  Future<void> _submitPermitRequest() async {
    if (_parentCellController.text.trim().isEmpty ||
        _addressController.text.trim().isEmpty ||
        _selectedProvince == null ||
        _reasonController.text.trim().isEmpty) {
      _showSnackBar("Please fill in all required fields.", isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();

      final payload = {
        "departure_date": _departureDate.toUtc().toIso8601String(),
        "parent_cell_number": _parentCellController.text.trim(),
        "destination_province": _selectedProvince,
        "destination_address": _addressController.text.trim(),
        "reason": _reasonController.text.trim(),
        "status": "REQUESTED",
      };

      final response = await http.post(
        Uri.parse('${ApiClass().getApiBaseUrl()}/leave-permits/'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 201) {
        _parentCellController.clear();
        _addressController.clear();
        _reasonController.clear();
        _selectedProvince = null;

        await _fetchData();
        setState(() => _currentViewIndex = 1);

        _showSuccessDialog(
          "Permit Requested!\nAwaiting room inspection by the attendant.",
        );
      } else {
        throw Exception("Server rejected the request.");
      }
    } catch (e) {
      _showSnackBar(
        "Failed to submit request. Please try again.",
        isError: true,
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  Future<void> _submitVisitor() async {
    if (_vNameController.text.trim().isEmpty ||
        _vContactController.text.trim().isEmpty ||
        _vIdController.text.trim().isEmpty) {
      _showSnackBar("Please fill in all visitor details.", isError: true);
      return;
    }

    if (_signatureController.isEmpty) {
      _showSnackBar("Visitor signature is strictly required.", isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final Uint8List? signatureBytes = await _signatureController.toPngBytes();
      final String signatureBase64 = base64Encode(signatureBytes!);

      final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
      final payload = {
        "visitor_name": _vNameController.text.trim(),
        "visitor_contact": _vContactController.text.trim(),
        "visitor_id_number": _vIdController.text.trim(),
        "visitor_signature": "data:image/png;base64,$signatureBase64",
      };

      final response = await http.post(
        Uri.parse('${ApiClass().getApiBaseUrl()}/visitor-registers/'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 201) {
        _vNameController.clear();
        _vContactController.clear();
        _vIdController.clear();
        _signatureController.clear();

        await _fetchData();
        setState(() => _showVisitorForm = false);
        _showSuccessDialog(
          "Visitor Registered!\nPresent the QR code at the security gate.",
        );
      } else {
        final errorData = jsonDecode(response.body);
        _showSnackBar(
          errorData['error'] ?? "Server rejected the request.",
          isError: true,
        );
      }
    } catch (e) {
      _showSnackBar(
        "Failed to register visitor. Please try again.",
        isError: true,
      );
    } finally {
      setState(() => _isSubmitting = false);
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

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Icon(
          CupertinoIcons.paperplane_fill,
          color: Colors.blueAccent,
          size: 64,
        ),
        content: Text(
          message,
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
                    "CLEARANCE",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: primaryColor,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Passes & Visitors",
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
                            "Request Leave",
                            0,
                            primaryColor,
                            textColor,
                            slateColor,
                          ),
                        ),
                        Expanded(
                          child: _buildSegmentButton(
                            "My Permits",
                            1,
                            primaryColor,
                            textColor,
                            slateColor,
                          ),
                        ),
                        Expanded(
                          child: _buildSegmentButton(
                            "Visitors",
                            2,
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
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(color: primaryColor),
                    )
                  : _currentViewIndex == 0
                  ? _buildRequestForm(primaryColor, slateColor, textColor)
                  : _currentViewIndex == 1
                  ? _buildHistoryList(primaryColor, slateColor, textColor)
                  : _buildVisitorSection(primaryColor, slateColor, textColor),
            ),
          ],
        ),
      ),
    );
  }

  // --- TAB 1: PERMIT REQUEST FORM ---
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
            const Text(
              "When are you leaving?",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: primaryColor.withOpacity(0.1)),
              ),
              child: _buildDateTile(
                "DEPARTURE DATE & TIME",
                _departureDate,
                _pickDateTime,
                slateColor,
                textColor,
              ),
            ),

            const SizedBox(height: 32),
            const Text(
              "Destination Details",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              value: _selectedProvince,
              hint: Text(
                "Select Province",
                style: TextStyle(color: slateColor.withOpacity(0.5)),
              ),
              dropdownColor: Theme.of(context).scaffoldBackgroundColor,
              icon: Icon(CupertinoIcons.chevron_down, color: slateColor),
              items: _provinces.map((String prov) {
                return DropdownMenuItem(
                  value: prov,
                  child: Text(
                    prov,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (val) => setState(() => _selectedProvince = val),
              decoration: _inputDecoration(
                primaryColor,
                slateColor,
                CupertinoIcons.map_pin_ellipse,
              ),
            ),

            const SizedBox(height: 16),
            _buildPremiumInput(
              "Destination Address",
              "Street name, City, Area code",
              _addressController,
              CupertinoIcons.house_fill,
              primaryColor,
              slateColor,
              textColor,
            ),

            const SizedBox(height: 32),
            const Text(
              "Guardian\'s Contact & Reason ",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),

            _buildPremiumInput(
              "Parent / Guardian Cell",
              "e.g. 082 123 4567",
              _parentCellController,
              CupertinoIcons.phone_fill,
              primaryColor,
              slateColor,
              textColor,
              isPhone: true,
            ),
            const SizedBox(height: 16),
            _buildPremiumInput(
              "Reason for Leave",
              "Briefly explain why you are leaving",
              _reasonController,
              CupertinoIcons.text_alignleft,
              primaryColor,
              slateColor,
              textColor,
              maxLines: 3,
            ),

            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitPermitRequest,
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
                        "SUBMIT PERMIT REQUEST",
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

  // --- TAB 2: LATEST PERMIT ONLY ---
  Widget _buildHistoryList(
    Color primaryColor,
    Color slateColor,
    Color textColor,
  ) {
    if (_myPermits.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.doc_text_fill,
              size: 64,
              color: slateColor.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              "No Permits Found",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "You haven't requested any exit permits yet.",
              style: TextStyle(color: slateColor),
            ),
          ],
        ),
      );
    }

    // TAKING ONLY THE LATEST PERMIT
    final permit = _myPermits.first;
    final String status = permit['status'] ?? 'REQUESTED';
    final String prov = permit['destination_province'] ?? 'Unknown';
    final String dateStr = permit['departure_date'] ?? '';
    final String qrData = permit['qr_reference'] ?? permit['id'].toString();

    Color statusColor;
    IconData statusIcon;

    switch (status) {
      case 'APPROVED':
        statusColor = Colors.green.shade500;
        statusIcon = CupertinoIcons.check_mark_circled_solid;
        break;
      case 'DENIED':
        statusColor = Colors.redAccent;
        statusIcon = CupertinoIcons.xmark_circle_fill;
        break;
      case 'INSPECTING':
        statusColor = Colors.blue.shade500;
        statusIcon = CupertinoIcons.search_circle_fill;
        break;
      default: // REQUESTED
        statusColor = Colors.orange.shade500;
        statusIcon = CupertinoIcons.time_solid;
    }

    return RefreshIndicator(
      color: primaryColor,
      onRefresh: _fetchData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.only(
          left: 24,
          right: 24,
          bottom: 120,
          top: 8,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                "Latest Active Permit",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: textColor,
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.03),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: primaryColor.withOpacity(0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                                "To: $prov",
                                style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Leaving: ${_formatDate(dateStr)}",
                                style: TextStyle(
                                  color: slateColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
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
                            border: Border.all(
                              color: statusColor.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(statusIcon, color: statusColor, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                status,
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
                  ),

                  if (status == 'APPROVED') ...[
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
                            "GATE CLEARANCE PASS",
                            style: TextStyle(
                              color: Colors.black.withOpacity(0.5),
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2.0,
                            ),
                          ),
                          const SizedBox(height: 16),
                          QrImageView(
                            data: qrData,
                            version: QrVersions.auto,
                            size: 160.0,
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black87,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "Present this code to security upon exit.",
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (status == 'DENIED') ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.1),
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(24),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            CupertinoIcons.exclamationmark_triangle_fill,
                            color: Colors.redAccent,
                            size: 20,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "Permit denied due to room damages flagged during inspection. Please see your attendant.",
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 20,
                        right: 20,
                        bottom: 20,
                      ),
                      child: Text(
                        "Awaiting attendant room inspection before clearance is granted.",
                        style: TextStyle(
                          color: slateColor.withOpacity(0.8),
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- TAB 3: VISITOR REGISTRATION ---
  Widget _buildVisitorSection(
    Color primaryColor,
    Color slateColor,
    Color textColor,
  ) {
    if (_showVisitorForm)
      return _buildVisitorForm(primaryColor, slateColor, textColor);

    // Check if there is currently an active visitor
    bool hasActiveVisitor = _myVisitors.any(
      (v) => v['status'] == 'PENDING' || v['status'] == 'SIGNED_IN',
    );

    return RefreshIndicator(
      color: primaryColor,
      onRefresh: _fetchData,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: ElevatedButton.icon(
              onPressed: hasActiveVisitor
                  ? () => _showSnackBar(
                      "You already have an active visitor. They must sign out first.",
                      isError: true,
                    )
                  : () => setState(() => _showVisitorForm = true),
              icon: const Icon(CupertinoIcons.add),
              label: Text(
                hasActiveVisitor
                    ? "Active Visitor Detected"
                    : "Register New Visitor",
              ),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: hasActiveVisitor ? Colors.grey : primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
            ),
          ),
          Expanded(
            child: _myVisitors.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          CupertinoIcons.person_3_fill,
                          size: 64,
                          color: slateColor.withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "No Visitors",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.only(
                      left: 24,
                      right: 24,
                      bottom: 120,
                      top: 8,
                    ),
                    itemCount: _myVisitors.length,
                    itemBuilder: (context, index) {
                      final v = _myVisitors[index];
                      final status = v['status'];

                      // Format Time In / Out
                      final timeIn = v['time_in'] != null
                          ? DateFormat(
                              'HH:mm',
                            ).format(DateTime.parse(v['time_in']).toLocal())
                          : '--:--';
                      final timeOut = v['time_out'] != null
                          ? DateFormat(
                              'HH:mm',
                            ).format(DateTime.parse(v['time_out']).toLocal())
                          : '--:--';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: primaryColor.withOpacity(0.1),
                          ),
                        ),
                        child: Column(
                          children: [
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 8,
                              ),
                              title: Text(
                                v['visitor_name'],
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: textColor,
                                ),
                              ),
                              subtitle: Text(
                                "Status: $status",
                                style: TextStyle(
                                  color: slateColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              trailing: Icon(
                                status == 'SIGNED_OUT'
                                    ? CupertinoIcons.check_mark_circled_solid
                                    : CupertinoIcons.time,
                                color: status == 'SIGNED_OUT'
                                    ? Colors.green
                                    : Colors.orange,
                                size: 28,
                              ),
                            ),

                            // Show Instant Time Updates
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 8,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  Column(
                                    children: [
                                      Text(
                                        "TIME IN",
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                          color: slateColor,
                                        ),
                                      ),
                                      Text(
                                        timeIn,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: textColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    height: 30,
                                    width: 1,
                                    color: slateColor.withOpacity(0.2),
                                  ),
                                  Column(
                                    children: [
                                      Text(
                                        "TIME OUT",
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                          color: slateColor,
                                        ),
                                      ),
                                      Text(
                                        timeOut,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: textColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            if (status != 'SIGNED_OUT') ...[
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
                                    QrImageView(
                                      data: v['qr_reference'],
                                      version: QrVersions.auto,
                                      size: 140.0,
                                    ),
                                    const SizedBox(height: 12),
                                    const Text(
                                      "Scan this at the security gate",
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black54,
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
          ),
        ],
      ),
    );
  }

  Widget _buildVisitorForm(
    Color primaryColor,
    Color slateColor,
    Color textColor,
  ) {
    String autoRoom = _studentData?['room_number_only'] ?? 'Unassigned';
    String autoBlock = _studentData?['block_name'] ?? 'Unassigned';

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(
          left: 24,
          right: 24,
          bottom: 120,
          top: 8,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  icon: Icon(CupertinoIcons.back, color: textColor),
                  onPressed: () => setState(() => _showVisitorForm = false),
                ),
                Text(
                  "New Visitor Register",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Auto-retrieved Host Data
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(
                    CupertinoIcons.building_2_fill,
                    size: 32,
                    color: primaryColor,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Visiting Room",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: slateColor,
                          ),
                        ),
                        Text(
                          "$autoBlock - Room $autoRoom",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
            _buildPremiumInput(
              "Visitor Initials & Surname",
              "e.g. JM Doe",
              _vNameController,
              CupertinoIcons.person_fill,
              primaryColor,
              slateColor,
              textColor,
            ),
            const SizedBox(height: 16),
            _buildPremiumInput(
              "Visitor Contact Number",
              "e.g. 082 123 4567",
              _vContactController,
              CupertinoIcons.phone_fill,
              primaryColor,
              slateColor,
              textColor,
              isPhone: true,
            ),
            const SizedBox(height: 16),
            _buildPremiumInput(
              "Visitor ID / Student Number",
              "Identity Verification",
              _vIdController,
              CupertinoIcons.creditcard_fill,
              primaryColor,
              slateColor,
              textColor,
            ),

            const SizedBox(height: 32),
            Text(
              "Visitor Signature",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: textColor,
              ),
            ),
            const SizedBox(height: 12),

            Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: primaryColor.withOpacity(0.3),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Signature(
                  controller: _signatureController,
                  height: 150,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _signatureController.clear(),
                icon: const Icon(CupertinoIcons.clear, size: 14),
                label: const Text(
                  "Clear Signature",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ),

            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitVisitor,
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
                        "GENERATE QR & REGISTER",
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

  // --- UI HELPERS ---
  Widget _buildSegmentButton(
    String text,
    int index,
    Color primaryColor,
    Color textColor,
    Color slateColor,
  ) {
    bool isSelected = _currentViewIndex == index;
    return GestureDetector(
      onTap: () => setState(() {
        _currentViewIndex = index;
        if (index != 2) _showVisitorForm = false;
      }),
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
    Color textCol, {
    int maxLines = 1,
    bool isPhone = false,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
      style: TextStyle(color: textCol, fontWeight: FontWeight.w600),
      decoration: _inputDecoration(primary, slate, icon).copyWith(
        hintText: hint,
        hintStyle: TextStyle(color: slate.withOpacity(0.5)),
      ),
    );
  }

  Widget _buildDateTile(
    String label,
    DateTime date,
    VoidCallback onTap,
    Color slate,
    Color textCol,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                color: slate,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              DateFormat('MMM dd').format(date),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: textCol,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('EEEE, HH:mm').format(date),
              style: TextStyle(
                color: slate,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String isoString) {
    try {
      final date = DateTime.parse(isoString).toLocal();
      return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
    } catch (e) {
      return "Recently";
    }
  }
}
