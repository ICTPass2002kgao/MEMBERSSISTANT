import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:mobile_app/components/api_class.dart';
import 'package:url_launcher/url_launcher.dart';

class MaintenanceTab extends StatefulWidget {
  const MaintenanceTab({super.key});

  @override
  State<MaintenanceTab> createState() => _MaintenanceTabState();
}

class _MaintenanceTabState extends State<MaintenanceTab> {
  bool _isLoadingHistory = true;
  bool _isSubmitting = false;
  bool _isProcessingPayment = false;
  String? _ratingSubmittingId;

  int _currentViewIndex = 0;
  List<dynamic> _myIssues = [];

  // Logic to check if there are any resolved issues that haven't been rated yet
  bool get _hasUnratedResolvedIssues {
    return _myIssues.any(
      (issue) =>
          issue['status'] == 'RESOLVED' && issue['attendant_rating'] == null,
    );
  }

  String _selectedLocation = 'My Room';
  final List<Map<String, dynamic>> _locations = [
    {'title': 'My Room', 'icon': CupertinoIcons.bed_double_fill},
    {'title': 'Shared Unit', 'icon': CupertinoIcons.layers_fill},
    {'title': 'Block Area', 'icon': CupertinoIcons.building_2_fill},
  ];

  String? _selectedCommonIssue;
  final TextEditingController _customTitleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  DateTime _availableFrom = DateTime.now().add(const Duration(hours: 2));
  DateTime _availableTo = DateTime.now().add(const Duration(hours: 6));

  final List<String> _commonIssues = [
    "Lost Key",
    "Light Voltage",
    "Door Handle",
    "Plugs",
    "Switch Fault",
    "Shelf / Wardrobe",
    "Mattress",
    "Other",
  ];

  @override
  void initState() {
    super.initState();
    _fetchMyIssues();
  }

  Future<void> _fetchMyIssues() async {
    setState(() => _isLoadingHistory = true);
    try {
      final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
      final response = await http.get(
        Uri.parse('${ApiClass().getApiBaseUrl()}/issues/'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _myIssues = data is List ? data : (data['results'] ?? []);
            _myIssues.sort(
              (a, b) =>
                  (b['created_at'] ?? '').compareTo(a['created_at'] ?? ''),
            );
            _isLoadingHistory = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  Future<void> _submitIssue() async {
    // Safety check: Don't allow submission if ratings are pending
    if (_hasUnratedResolvedIssues) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Action Blocked: Complete pending ratings first."),
        ),
      );
      return;
    }

    String finalTitle = (_selectedCommonIssue == "Other")
        ? _customTitleController.text
        : (_selectedCommonIssue ?? "");

    if (finalTitle.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select or type a specific issue."),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
      String finalDescription =
          "[Location: $_selectedLocation]\n${_descController.text.trim()}";

      final payload = {
        "custom_issue_title": finalTitle,
        "description": finalDescription,
        "available_from": _availableFrom.toUtc().toIso8601String(),
        "available_to": _availableTo.toUtc().toIso8601String(),
        "status": "PENDING",
      };

      final response = await http.post(
        Uri.parse('${ApiClass().getApiBaseUrl()}/issues/'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        final String newIssueId = responseData['id'].toString();

        _selectedCommonIssue = null;
        _selectedLocation = 'My Room';
        _customTitleController.clear();
        _descController.clear();

        await _fetchMyIssues();
        setState(() {
          _currentViewIndex = 1;
        });

        if (finalTitle == "Lost Key") {
          await _handlePayment(newIssueId);
        } else {
          _showSuccessDialog();
        }
      } else {
        throw Exception("Server rejected payload");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Submission failed. Check connection or inputs."),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _submitRating(String issueId, int rating) async {
    setState(() => _ratingSubmittingId = issueId);
    try {
      final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
      final response = await http.patch(
        Uri.parse('${ApiClass().getApiBaseUrl()}/issues/$issueId/'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'attendant_rating': rating}),
      );

      if (response.statusCode == 200) {
        setState(() {
          final issueIndex = _myIssues.indexWhere(
            (i) => i['id'].toString() == issueId,
          );
          if (issueIndex != -1) {
            _myIssues[issueIndex]['attendant_rating'] = rating;
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Thank you! Rating submitted.",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        _fetchMyIssues();
      } else {
        throw Exception("Failed to save rating");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Failed to submit rating."),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _ratingSubmittingId = null);
    }
  }

  Future<void> _handlePayment(String issueId) async {
    setState(() => _isProcessingPayment = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User session invalid.");
      final idToken = await user.getIdToken();
      final payload = {"issue_id": issueId};

      final response = await http.post(
        Uri.parse('${ApiClass().getApiBaseUrl()}/create-payment-link/'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String paymentUrl = data['paymentLink'];
        final Uri url = Uri.parse(paymentUrl);
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.inAppBrowserView);
        } else {
          throw Exception("Could not open payment link.");
        }
      } else {
        throw Exception("Payment failed to initialize");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Payment Error: ${e.toString()}"),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isProcessingPayment = false);
    }
  }

  String _getCollectionInstruction() {
    final int currentHour = DateTime.now().hour;
    if (currentHour >= 17 || currentHour < 8) {
      return "Payment verified. The office is currently closed. Please collect your key tomorrow between 08:00 and 17:00.";
    } else {
      return "Payment verified. Your new key is ready. Please collect it at the office now.";
    }
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
                    "MAINTENANCE",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: primaryColor,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Service Hub",
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
                            "Report Issue",
                            0,
                            primaryColor,
                            textColor,
                            slateColor,
                          ),
                        ),
                        Expanded(
                          child: _buildSegmentButton(
                            "My Tickets",
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
              child: Stack(
                children: [
                  _currentViewIndex == 0
                      ? _buildReportForm(primaryColor, slateColor, textColor)
                      : _buildHistoryList(primaryColor, slateColor, textColor),
                  if (_isProcessingPayment)
                    Container(
                      color: theme.scaffoldBackgroundColor.withOpacity(0.8),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(color: primaryColor),
                              const SizedBox(height: 16),
                              Text(
                                "Securing Checkout...",
                                style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportForm(
    Color primaryColor,
    Color slateColor,
    Color textColor,
  ) {
    // LOCK MECHANISM: If unrated issues exist, show this instead of the form
    if (!_isLoadingHistory && _hasUnratedResolvedIssues) {
      return Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                CupertinoIcons.star_circle_fill,
                color: Colors.amber,
                size: 80,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "Feedback Required",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: textColor,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "To maintain high service standards, you must rate the staff for your previous resolved issues before logging a new ticket.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: slateColor,
                fontSize: 14,
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () => setState(() => _currentViewIndex = 1),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  "VIEW PENDING RATINGS",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(left: 24, right: 24, bottom: 120, top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Where is the issue located?",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          Row(
            children: _locations.map((loc) {
              bool isSelected = _selectedLocation == loc['title'];
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedLocation = loc['title']),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? primaryColor
                          : primaryColor.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? primaryColor
                            : primaryColor.withOpacity(0.1),
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: primaryColor.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : [],
                    ),
                    child: Column(
                      children: [
                        Icon(
                          loc['icon'],
                          color: isSelected
                              ? Colors.white
                              : slateColor.withOpacity(0.6),
                          size: 24,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          loc['title'],
                          style: TextStyle(
                            color: isSelected ? Colors.white : slateColor,
                            fontWeight: isSelected
                                ? FontWeight.w900
                                : FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),
          const Text(
            "What is the problem?",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _commonIssues.map((issue) {
              bool isSelected = _selectedCommonIssue == issue;
              return GestureDetector(
                onTap: () => setState(() => _selectedCommonIssue = issue),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? primaryColor
                        : primaryColor.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? primaryColor
                          : primaryColor.withOpacity(0.1),
                    ),
                  ),
                  child: Text(
                    issue,
                    style: TextStyle(
                      color: isSelected ? Colors.white : slateColor,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          if (_selectedCommonIssue == "Other") ...[
            const SizedBox(height: 24),
            _buildPremiumInput(
              "Custom Title",
              "Describe the issue in 2-3 words",
              _customTitleController,
              Icons.edit_note,
              primaryColor,
              slateColor,
              textColor,
            ),
          ],
          const SizedBox(height: 24),
          _buildPremiumInput(
            "Additional Details",
            "Any extra info for the attendant?",
            _descController,
            Icons.description_outlined,
            primaryColor,
            slateColor,
            textColor,
            maxLines: 3,
          ),
          const SizedBox(height: 32),
          const Text(
            "Technician Access Window",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: primaryColor.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildDateTile(
                    "FROM",
                    _availableFrom,
                    () => _pickDateTime(true),
                    slateColor,
                    textColor,
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: primaryColor.withOpacity(0.1),
                ),
                Expanded(
                  child: _buildDateTile(
                    "UNTIL",
                    _availableTo,
                    () => _pickDateTime(false),
                    slateColor,
                    textColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitIssue,
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
                  : Text(
                      _selectedCommonIssue == "Lost Key"
                          ? "PAY & SUBMIT TICKET"
                          : "SUBMIT TICKET",
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList(
    Color primaryColor,
    Color slateColor,
    Color textColor,
  ) {
    if (_isLoadingHistory)
      return Center(child: CircularProgressIndicator(color: primaryColor));
    if (_myIssues.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.wrench_fill,
              size: 64,
              color: slateColor.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              "No Tickets Found",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "You haven't reported any issues yet.",
              style: TextStyle(color: slateColor),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: primaryColor,
      onRefresh: _fetchMyIssues,
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
        itemCount: _myIssues.length,
        itemBuilder: (context, index) {
          final issue = _myIssues[index];
          final String status = issue['status'] ?? 'PENDING';
          final String title = issue['custom_issue_title'] ?? 'Reported Issue';
          final String desc =
              issue['description'] ?? 'No description provided.';
          final String dateStr = issue['created_at'] ?? '';
          final String issueId = issue['id'].toString();
          final String attendantName =
              issue['assigned_attendant_name'] ?? 'the attendant';
          final int? attendantRating = issue['attendant_rating'];

          Color statusColor;
          IconData statusIcon;
          switch (status) {
            case 'AWAITING_PAYMENT':
              statusColor = Colors.redAccent;
              statusIcon = CupertinoIcons.creditcard_fill;
              break;
            case 'READY_FOR_COLLECTION':
              statusColor = Colors.purpleAccent;
              statusIcon = CupertinoIcons.collections_solid;
              break;
            case 'RESOLVED':
              statusColor = Colors.green.shade500;
              statusIcon = CupertinoIcons.check_mark_circled_solid;
              break;
            case 'ATTENDING':
              statusColor = Colors.blue.shade500;
              statusIcon = CupertinoIcons.time_solid;
              break;
            default:
              statusColor = Colors.orange.shade500;
              statusIcon = CupertinoIcons.clock_fill;
          }

          String displayDesc = desc;
          String? extractedLocation;
          final locMatch = RegExp(r'^\[Location: (.*?)\]\n').firstMatch(desc);
          if (locMatch != null) {
            extractedLocation = locMatch.group(1);
            displayDesc = desc.substring(locMatch.end);
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.03),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: primaryColor.withOpacity(0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                _formatDate(dateStr),
                                style: TextStyle(
                                  color: slateColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (extractedLocation != null) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    extractedLocation,
                                    style: TextStyle(
                                      color: primaryColor,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ],
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
                        border: Border.all(color: statusColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, color: statusColor, size: 14),
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
                if (status == 'READY_FOR_COLLECTION') ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.purpleAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.purpleAccent.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          CupertinoIcons.info_circle_fill,
                          color: Colors.purpleAccent,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _getCollectionInstruction(),
                            style: const TextStyle(
                              color: Colors.purpleAccent,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Text(
                    displayDesc,
                    style: TextStyle(
                      color: slateColor.withOpacity(0.8),
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ],
                if (status == 'RESOLVED') ...[
                  const SizedBox(height: 20),
                  _buildRatingWidget(
                    issueId,
                    attendantName,
                    attendantRating,
                    textColor,
                    slateColor,
                  ),
                ],
                if (status == 'AWAITING_PAYMENT') ...[
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () => _handlePayment(issueId),
                      icon: const Icon(CupertinoIcons.lock_fill, size: 16),
                      label: const Text(
                        "PAY NOW TO UNLOCK TICKET",
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          letterSpacing: 1.0,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
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

  Widget _buildRatingWidget(
    String issueId,
    String attendantName,
    int? currentRating,
    Color textColor,
    Color slateColor,
  ) {
    if (_ratingSubmittingId == issueId) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.amber.shade200),
        ),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(color: Colors.amber),
          ),
        ),
      );
    }

    if (currentRating != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.amber.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.amber.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(
              CupertinoIcons.checkmark_seal_fill,
              color: Colors.amber.shade600,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "You rated $attendantName",
                style: TextStyle(
                  color: Colors.amber.shade800,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            Row(
              children: List.generate(
                5,
                (index) => Padding(
                  padding: const EdgeInsets.only(left: 2),
                  child: Icon(
                    index < currentRating
                        ? CupertinoIcons.star_fill
                        : CupertinoIcons.star,
                    color: Colors.amber,
                    size: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.shade300, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            "How was $attendantName's service?",
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              return GestureDetector(
                onTap: () => _submitRating(issueId, index + 1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6.0),
                  child: Icon(
                    CupertinoIcons.star_fill,
                    color: Colors.amber.shade200,
                    size: 40,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          const Text(
            "Tap a star to submit rating",
            style: TextStyle(
              color: Colors.grey,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

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

  Widget _buildPremiumInput(
    String label,
    String hint,
    TextEditingController controller,
    IconData icon,
    Color primary,
    Color slate,
    Color textCol, {
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          style: TextStyle(color: textCol, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: slate.withOpacity(0.5)),
            prefixIcon: Icon(icon, color: slate),
            filled: true,
            fillColor: primary.withOpacity(0.05),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: primary.withOpacity(0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: primary, width: 2),
            ),
          ),
        ),
      ],
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
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
            const SizedBox(height: 4),
            Text(
              DateFormat('MMM dd').format(date),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: textCol,
              ),
            ),
            Text(
              DateFormat('HH:mm').format(date),
              style: TextStyle(
                color: slate,
                fontSize: 12,
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

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Icon(
          CupertinoIcons.check_mark_circled_solid,
          color: Colors.green,
          size: 64,
        ),
        content: const Text(
          "Ticket Logged!\nCheck 'My Tickets' to track its status.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "OK",
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDateTime(bool isFrom) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: isFrom ? _availableFrom : _availableTo,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 14)),
    );
    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(
          isFrom ? _availableFrom : _availableTo,
        ),
      );
      if (pickedTime != null) {
        setState(() {
          final newDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
          if (isFrom) {
            _availableFrom = newDateTime;
          } else {
            _availableTo = newDateTime;
          }
        });
      }
    }
  }
}
