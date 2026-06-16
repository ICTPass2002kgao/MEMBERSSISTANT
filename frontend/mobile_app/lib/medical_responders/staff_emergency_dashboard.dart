import 'dart:convert';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mobile_app/components/api_class.dart';

// IMPORTANT: Import the new screen here
import 'patient_medical_file_screen.dart';

class StaffEmergencyDashboard extends StatefulWidget {
  // Callback injected from the MainMenu to switch tabs and pass coordinates
  final Function(double lat, double lng) onGetDirections;

  const StaffEmergencyDashboard({super.key, required this.onGetDirections});

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

        // Only keep active incidents
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
          _errorMessage = "Server error (${response.statusCode}).";
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Network connection failed.";
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

  // --- NEW: Simply navigate to the dedicated medical file screen ---
  void _openMedicalFileScreen(String reportId, String patientName, String? patientId) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => PatientMedicalFileScreen(
          reportId: reportId,
          patientId: patientId,
          fallbackName: patientName,
        ),
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
        child: ElevatedButton(
          onPressed: () {
            setState(() => _isLoading = true);
            _fetchEmergencies();
          },
          child: const Text("RETRY"),
        ),
      );
    }

    if (_emergencies.isEmpty) {
      return Center(
        child: Text(
          "No active emergencies.",
          style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5)),
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

          // Use Patient Name, Fallback to "Unidentified" if AI failed
          final String patientName =
              report['patient_name'] ?? "Unidentified Patient";

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
                          Row(
                            children: [
                              // Added the custom shaking icon here
                              if (isPending) ...[
                                const ShakingWarningIcon(),
                                const SizedBox(width: 8),
                              ],
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
                                child: Text(
                                  "CRITICAL - $status",
                                  style: TextStyle(
                                    color: isPending
                                        ? Colors.redAccent
                                        : Colors.orangeAccent.shade700,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
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
                        "Patient: $patientName",
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),

                      const SizedBox(height: 8),
                      // Notice: No raw coordinates. Just clean text description.
                      Text(
                        report['description'] ??
                            "Location tracked via internal systems.",
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),

                      const SizedBox(height: 24),

                      // SIDE-BY-SIDE BUTTONS
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                if (report['latitude'] != null &&
                                    report['longitude'] != null) {
                                  // This triggers the map callback in staff_main_menu.dart
                                  widget.onGetDirections(
                                    report['latitude'],
                                    report['longitude'],
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        "No route coordinates available.",
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(
                                CupertinoIcons.map_fill,
                                size: 16,
                              ),
                              label: const Text(
                                "DIRECTIONS",
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _openMedicalFileScreen(
                                report['id'].toString(),
                                patientName,
                                report['patient_id']?.toString(),
                              ),
                              icon: const Icon(
                                CupertinoIcons.doc_text_fill,
                                size: 16,
                              ),
                              label: const Text(
                                "MEDICAL FILE",
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.redAccent,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: Colors.redAccent.withOpacity(0.3),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
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

// Custom Widget for the Shaking Icon
class ShakingWarningIcon extends StatefulWidget {
  const ShakingWarningIcon({super.key});

  @override
  State<ShakingWarningIcon> createState() => _ShakingWarningIconState();
}

class _ShakingWarningIconState extends State<ShakingWarningIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Rotate back and forth rapidly
        final angle = (_controller.value - 0.5) * 0.5;
        return Transform.rotate(
          angle: angle,
          child: const Icon(
            CupertinoIcons.bell_circle_fill,
            color: Colors.redAccent,
            size: 22,
          ),
        );
      },
    );
  }
}