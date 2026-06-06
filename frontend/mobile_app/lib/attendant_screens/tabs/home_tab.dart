import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mobile_app/components/api_class.dart';

class AttendantHomeTab extends StatefulWidget {
  final String name;
  final String role;
  final String initials;
  final Function(int) onNavigate;
  final VoidCallback onLogout;

  const AttendantHomeTab({
    super.key,
    required this.name,
    required this.role,
    required this.initials,
    required this.onNavigate,
    required this.onLogout,
  });

  @override
  State<AttendantHomeTab> createState() => _AttendantHomeTabState();
}

class _AttendantHomeTabState extends State<AttendantHomeTab> {
  bool _isLoading = true;
  List<dynamic> _pendingIssues = [];
  dynamic _myActiveIssue;
  List<dynamic> _activePermits = [];
  String _currentUserUid = '';

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      _currentUserUid = user.uid;
      final idToken = await user.getIdToken();

      final headers = {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      };

      final responses = await Future.wait([
        http.get(
          Uri.parse('${ApiClass().getApiBaseUrl()}/issues/'),
          headers: headers,
        ),
        http.get(
          Uri.parse('${ApiClass().getApiBaseUrl()}/leave-permits/'),
          headers: headers,
        ),
      ]);

      if (responses[0].statusCode == 200 && responses[1].statusCode == 200) {
        final issuesData = jsonDecode(responses[0].body);
        final permitsData = jsonDecode(responses[1].body);

        List<dynamic> allIssues = issuesData is List
            ? issuesData
            : (issuesData['results'] ?? []);
        List<dynamic> fetchedPermits = permitsData is List
            ? permitsData
            : (permitsData['results'] ?? []);

        if (mounted) {
          setState(() {
            // Find if I am already resolving something
            _myActiveIssue = allIssues.firstWhere(
              (i) =>
                  i['status'] == 'ATTENDING' &&
                  i['assigned_attendant_uid'] == _currentUserUid,
              orElse: () => null,
            );

            // Filter for other PENDING issues
            _pendingIssues = allIssues
                .where((i) => i['status'] == 'PENDING')
                .toList();
            _pendingIssues.sort(
              (a, b) => (b['is_priority'] ? 1 : 0).compareTo(
                a['is_priority'] ? 1 : 0,
              ),
            );

            _activePermits = fetchedPermits
                .where((p) => p['status'] == 'REQUESTED')
                .toList();
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- API ACTION: UPDATE STATUS ---
  Future<void> _updateStatus(String issueId, String newStatus) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();

      final response = await http.patch(
        Uri.parse('${ApiClass().getApiBaseUrl()}/issues/$issueId/'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'status': newStatus}),
      );

      if (response.statusCode == 200) {
        _fetchDashboardData(); // Refresh UI
      } else {
        final error = jsonDecode(response.body);
        _showNotification(error['error'] ?? "Update failed");
      }
    } catch (e) {
      _showNotification("Network Error");
    }
  }

  void _showNotification(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FF),
      body: RefreshIndicator(
        onRefresh: _fetchDashboardData,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildSliverHeader(theme),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // --- ACTIVE MISSION ---
                  if (_myActiveIssue != null) ...[
                    _buildLabel("CURRENT MISSION"),
                    const SizedBox(height: 12),
                    _buildActiveTaskCard(_myActiveIssue),
                    const SizedBox(height: 32),
                  ],

                  // --- LIVE ALERTS ---
                  _buildLabel("AVAILABLE ALERTS"),
                  const SizedBox(height: 16),

                  if (_isLoading)
                    const Center(child: CupertinoActivityIndicator())
                  else if (_pendingIssues.isEmpty &&
                      _activePermits.isEmpty &&
                      _myActiveIssue == null)
                    _buildEmptyState()
                  else ...[
                    ..._pendingIssues.map((issue) => _buildIssueCard(issue)),
                    ..._activePermits.map((permit) => _buildPermitCard(permit)),
                  ],
                  const SizedBox(height: 120),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverHeader(ThemeData theme) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "OVERWATCH",
                  style: TextStyle(
                    letterSpacing: 3,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: Colors.blueAccent,
                  ),
                ),
                Text(
                  widget.name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            GestureDetector(
              onTap: widget.onLogout,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.blueAccent.withOpacity(0.2)),
                ),
                child: CircleAvatar(
                  backgroundColor: Colors.blueAccent,
                  radius: 22,
                  child: Text(
                    widget.initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
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

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.5,
        color: Colors.blueGrey,
      ),
    );
  }

  // --- DESIGN: ACTIVE TASK (RESOLVING) ---
  Widget _buildActiveTaskCard(dynamic issue) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF13131F),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.blueAccent.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  CupertinoIcons.hammer_fill,
                  color: Colors.blueAccent,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  "ROOM ${issue['room_number']}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              issue['custom_issue_title'],
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),

            // Neon Status Switcher
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    "MARK RESOLVED",
                    Colors.greenAccent,
                    () => _updateStatus(issue['id'], 'RESOLVED'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- DESIGN: PENDING ISSUE ---
  Widget _buildIssueCard(dynamic issue) {
    bool isUrgent = issue['is_priority'] ?? false;
    Color accent = isUrgent ? Colors.redAccent : Colors.orangeAccent;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => _myActiveIssue == null
              ? _updateStatus(issue['id'], 'ATTENDING')
              : _showNotification("You are already on a mission!"),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                _buildIconContainer(accent, CupertinoIcons.wrench_fill),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Room ${issue['room_number']}",
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        issue['custom_issue_title'],
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  _myActiveIssue == null ? "CLAIM" : "LOCKED",
                  style: TextStyle(
                    color: _myActiveIssue == null ? accent : Colors.grey,
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPermitCard(dynamic permit) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          _buildIconContainer(
            Colors.purpleAccent,
            CupertinoIcons.doc_text_search,
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              "Exit Inspection Required",
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          const Icon(
            CupertinoIcons.chevron_right,
            size: 16,
            color: Colors.grey,
          ),
        ],
      ),
    );
  }

  Widget _buildIconContainer(Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _buildActionButton(String label, Color color, VoidCallback onTap) {
    return CupertinoButton(
      onPressed: onTap,
      child: Container(
        height: 45,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withOpacity(0.5)),
          boxShadow: [BoxShadow(color: color.withOpacity(0.2), blurRadius: 10)],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.only(top: 50),
        child: Text(
          "All Clear. No alerts.",
          style: TextStyle(color: Colors.grey),
        ),
      ),
    );
  }
}
