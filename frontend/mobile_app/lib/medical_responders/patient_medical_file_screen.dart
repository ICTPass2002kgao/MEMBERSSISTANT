import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mobile_app/components/api_class.dart';

class PatientMedicalFileScreen extends StatefulWidget {
  final String reportId;
  final String? patientId;
  final String fallbackName;

  const PatientMedicalFileScreen({
    super.key,
    required this.reportId,
    required this.patientId,
    required this.fallbackName,
  });

  @override
  State<PatientMedicalFileScreen> createState() =>
      _PatientMedicalFileScreenState();
}

class _PatientMedicalFileScreenState extends State<PatientMedicalFileScreen> {
  bool _isLoading = true;
  String _errorMessage = '';
  Map<String, dynamic>? _medicalData;

  @override
  void initState() {
    super.initState();
    _fetchFullMedicalProfile();
  }

  Future<void> _fetchFullMedicalProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _errorMessage = "Authentication error. Please log in again.";
          _isLoading = false;
        });
        return;
      }

      final idToken = await user.getIdToken();

      final response = await http.post(
        Uri.parse(
          '${ApiClass().getApiBaseUrl()}/emergencies/unlock-medical-data/',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({
          'report_id': widget.reportId,
          'patient_id': widget.patientId,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          _medicalData = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        final error = jsonDecode(response.body)['error'] ?? "Access Denied.";
        setState(() {
          _errorMessage = error;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Network error unlocking file.";
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = theme.scaffoldBackgroundColor;
    final textColor = theme.colorScheme.onSurface;
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(CupertinoIcons.back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "PATIENT FILE",
          style: TextStyle(
            color: Colors.redAccent,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
          ),
        ),
      ),
      body: _buildBody(theme, textColor, primaryColor),
    );
  }

  Widget _buildBody(ThemeData theme, Color textColor, Color primaryColor) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.redAccent),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
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
                _errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                ),
                child: const Text(
                  "GO BACK",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_medicalData == null) return const SizedBox.shrink();
 
    final String faceUrl = _medicalData!['face_url'] ?? '';
    final String studentName =
        _medicalData!['student_name'] ?? widget.fallbackName;
    final String studentNumber =
        _medicalData!['student_number'] ?? 'Unknown ID';
    final String blockName = _medicalData!['block_name'] ?? 'Unknown Block';
    final String roomNumber = _medicalData!['room_number'] ?? 'Unknown Room'; 

    //
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. IDENTITY & LOCATION HEADER
          Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.redAccent.withOpacity(0.5),
                      width: 3,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 56,
                    backgroundColor: Colors.redAccent.withOpacity(0.1),
                    backgroundImage: faceUrl.isNotEmpty
                        ? NetworkImage(faceUrl)
                        : null,
                    child: faceUrl.isEmpty
                        ? const Icon(
                            CupertinoIcons.person_fill,
                            size: 48,
                            color: Colors.redAccent,
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  studentName,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  studentNumber,
                  style: TextStyle(
                    color: theme.colorScheme.onSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CupertinoIcons.building_2_fill,
                        size: 16,
                        color: primaryColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "$blockName • Room $roomNumber",
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: primaryColor,
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

          // 2. MEDICAL DATA
          _buildSectionHeader("CLINICAL DATA", Colors.redAccent),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.05),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
            ),
            child: Column(
              children: [
                _buildDataRow(
                  "Blood Type",
                  _medicalData!['blood_type'] ?? "Unknown",
                  CupertinoIcons.drop_fill,
                  Colors.redAccent,
                ),
                const SizedBox(height: 20),
                _buildDataRow(
                  "Allergies",
                  _medicalData!['allergies'] ?? "None known",
                  CupertinoIcons.exclamationmark_triangle_fill,
                  Colors.orange,
                ),
                const SizedBox(height: 20),
                _buildDataRow(
                  "Conditions",
                  _medicalData!['medical_conditions'] ?? "None recorded",
                  CupertinoIcons.heart_fill,
                  Colors.pink,
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // 3. EMERGENCY CONTACT
          _buildSectionHeader("EMERGENCY CONTACT", Colors.green),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.05),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.green.withOpacity(0.2)),
            ),
            child: _buildDataRow(
              _medicalData!['emergency_contact_relation'] ?? "Contact",
              "${_medicalData!['emergency_contact_name']}\n${_medicalData!['emergency_contact_phone']}",
              CupertinoIcons.phone_fill,
              Colors.green,
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: color,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildDataRow(
    String label,
    String value,
    IconData icon,
    Color iconColor,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 22),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
