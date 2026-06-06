import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mobile_app/components/api_class.dart';

class ApplicationsTab extends StatefulWidget {
  const ApplicationsTab({super.key});

  @override
  State<ApplicationsTab> createState() => _ApplicationsTabState();
}

class _ApplicationsTabState extends State<ApplicationsTab> {
  bool _isLoading = true;
  List<dynamic> _applications = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchApplications();
  }

  Future<void> _fetchApplications() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not authenticated");
      
      final idToken = await user.getIdToken();

      // Ensure this matches your backend route for fetching a student's applications
      final response = await http.get(
        Uri.parse('${ApiClass().getApiBaseUrl()}/apply-accommodation/'), 
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _applications = data is List ? data : (data['results'] ?? []);
            _isLoading = false;
          });
        }
      } else {
        throw Exception("Failed to load applications");
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Color _getStatusColor(String? status, Color primary) {
    switch (status?.toLowerCase()) {
      case 'approved':
      case 'accepted':
        return Colors.green;
      case 'rejected':
      case 'declined':
        return Colors.redAccent;
      case 'pending':
      default:
        return Colors.orangeAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Text(
                'My Applications',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            Expanded(
              child: _buildBody(theme, primary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme, Color primary) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: primary));
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(CupertinoIcons.exclamationmark_circle, color: theme.colorScheme.onSecondary, size: 48),
              const SizedBox(height: 16),
              Text(
                "Could not load applications.\n$_errorMessage",
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.onSecondary),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _errorMessage = null;
                  });
                  _fetchApplications();
                },
                child: const Text("Retry"),
              )
            ],
          ),
        ),
      );
    }

    if (_applications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.doc_text_search, size: 64, color: primary.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(
              'No Applications Yet',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
            ),
            const SizedBox(height: 8),
            Text(
              'You have not applied to any accommodations.',
              style: TextStyle(color: theme.colorScheme.onSecondary),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchApplications,
      color: primary,
      child: ListView.builder(
        padding: const EdgeInsets.only(left: 24, right: 24, bottom: 100), // padding for bottom nav
        itemCount: _applications.length,
        itemBuilder: (context, index) {
          final app = _applications[index];
          // Adapt these keys based on your actual API response structure
          final accName = app['accommodation_name'] ?? 'Unknown Residence';
          final status = app['status'] ?? 'Pending';
          final dateStr = app['created_at'] ?? '';
          
          final statusColor = _getStatusColor(status, primary);

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: primary.withOpacity(0.1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          accName,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          status.toString().toUpperCase(),
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(CupertinoIcons.calendar, size: 16, color: theme.colorScheme.onSecondary),
                      const SizedBox(width: 8),
                      Text(
                        dateStr.isNotEmpty ? dateStr.split('T').first : 'Date unknown',
                        style: TextStyle(color: theme.colorScheme.onSecondary, fontSize: 14),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}