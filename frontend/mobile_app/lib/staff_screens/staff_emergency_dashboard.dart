import 'dart:convert';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mobile_app/components/api_class.dart';
import 'package:mobile_app/staff_screens/face_verification_screen.dart';

class StaffEmergencyDashboard extends StatefulWidget {
  const StaffEmergencyDashboard({super.key});

  @override
  State<StaffEmergencyDashboard> createState() =>
      _StaffEmergencyDashboardState();
}

class _StaffEmergencyDashboardState extends State<StaffEmergencyDashboard> {
  List<dynamic> _emergencies = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchEmergencies();
  }

  Future<void> _fetchEmergencies() async {
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

      final response = await http.get(
        Uri.parse('${ApiClass().getApiBaseUrl()}/emergencies/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<dynamic> fetchedEmergencies = data is List
            ? data
            : (data['results'] ?? []);

        // Only keep active incidents that require staff intervention
        fetchedEmergencies = fetchedEmergencies
            .where((e) => e['status'] != 'RESOLVED')
            .toList();

        setState(() {
          _emergencies = fetchedEmergencies;
          _isLoading = false;
          _errorMessage = '';
        });
      } else {
        setState(() {
          _errorMessage =
              "Server error (${response.statusCode}). Failed to sync dispatches.";
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage =
              "Network connection failed. Check your local connection.";
          _isLoading = false;
        });
      }
    }
  }

  String _formatDate(String isoDate) {
    try {
      DateTime date = DateTime.parse(isoDate).toLocal();
      return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
    } catch (e) {
      return "Active Now";
    }
  }

  void _triggerDualScanProtocol(
    BuildContext context,
    String reportId,
    String studentId,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: const [
            Icon(CupertinoIcons.lock_shield_fill, color: Colors.redAccent),
            SizedBox(width: 8),
            Text(
              "Security Protocol",
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
          ],
        ),
        content: const Text(
          "Accessing protected POPIA health records requires biometric verification. Staff will perform live validation; student validation will bypass liveness checks for medical compliance.",
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "CANCEL",
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              Navigator.pop(context);
              final Map<String, dynamic>? medicalRecord = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FaceVerificationScreen(
                    reportId: reportId,
                    studentId: studentId,
                  ),
                ),
              );
              if (medicalRecord != null) {
                debugPrint(
                  "Decrypted payload matching: ${medicalRecord.toString()}",
                );
              }
            },
            child: const Text(
              "PROCEED TO SCAN",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
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

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "EMERGENCY DISPATCH",
          style: TextStyle(
            color: Colors.redAccent.shade400,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
          ),
        ),
        centerTitle: true,
      ),
      body: _buildBody(theme, primaryColor),
    );
  }

  Widget _buildBody(ThemeData theme, Color primaryColor) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: Colors.redAccent.shade400),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                CupertinoIcons.exclamationmark_triangle,
                color: Colors.redAccent.shade400,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() => _isLoading = true);
                  _fetchEmergencies();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                ),
                child: const Text(
                  "RETRY",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_emergencies.isEmpty) {
      return RefreshIndicator(
        color: Colors.redAccent,
        onRefresh: _fetchEmergencies,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.3),
            Center(
              child: Column(
                children: [
                  Icon(
                    CupertinoIcons.checkmark_shield_fill,
                    color: Colors.green.withOpacity(0.5),
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "All Clear",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "No active emergency dispatches.",
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: Colors.redAccent,
      onRefresh: _fetchEmergencies,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        itemCount: _emergencies.length,
        itemBuilder: (context, index) {
          final report = _emergencies[index];
          final String status = report['status'] ?? 'UNKNOWN';
          final bool isPending = status == 'PENDING';

          return Container(
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              color: isPending
                  ? Colors.redAccent.withOpacity(0.05)
                  : Colors.orangeAccent.withOpacity(0.05),
              border: Border.all(
                color: isPending
                    ? Colors.redAccent.withOpacity(0.3)
                    : Colors.orangeAccent.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isPending
                                  ? Colors.redAccent.withOpacity(0.15)
                                  : Colors.orangeAccent.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isPending) ...[
                                  const Icon(
                                    CupertinoIcons.circle_fill,
                                    color: Colors.redAccent,
                                    size: 8,
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                Text(
                                  "CRITICAL - $status",
                                  style: TextStyle(
                                    color: isPending
                                        ? Colors.redAccent
                                        : Colors.orangeAccent.shade700,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            _formatDate(report['created_at'] ?? ''),
                            style: TextStyle(
                              color: theme.colorScheme.onSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "${report['student_name'] ?? 'Unknown'} ${report['student_surname'] ?? ''}"
                            .trim(),
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            CupertinoIcons.location_solid,
                            color: primaryColor,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Lat: ${report['latitude']?.toStringAsFixed(4) ?? 'N/A'}, Lng: ${report['longitude']?.toStringAsFixed(4) ?? 'N/A'}",
                            style: TextStyle(
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.7,
                              ),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: () => _triggerDualScanProtocol(
                            context,
                            report['id'].toString(),
                            report['student']?.toString() ?? '',
                          ),
                          icon: const Icon(
                            CupertinoIcons.lock_shield,
                            size: 20,
                          ),
                          label: const Text(
                            "UNLOCK MEDICAL FILE",
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.redAccent,
                            elevation: 5,
                            shadowColor: Colors.black.withOpacity(0.2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: Colors.redAccent.withOpacity(0.3),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
