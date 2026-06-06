import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mobile_app/components/api_class.dart';

class AttendantPermitsTab extends StatefulWidget {
  const AttendantPermitsTab({super.key});

  @override
  State<AttendantPermitsTab> createState() => _AttendantPermitsTabState();
}

class _AttendantPermitsTabState extends State<AttendantPermitsTab> {
  List<dynamic> _pendingPermits = [];
  List<dynamic> _completedPermits = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPermits();
  }

  Future<void> _fetchPermits() async {
    setState(() => _isLoading = true);
    try {
      final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();

      // Fetch all permits without strict status filter
      final response = await http.get(
        Uri.parse('${ApiClass().getApiBaseUrl()}/leave-permits/'),
        headers: {'Authorization': 'Bearer $idToken'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<dynamic> fetchedList = data is List
            ? data
            : (data['results'] ?? []);

        if (mounted) {
          setState(() {
            // Sort active jobs to the pending tab
            _pendingPermits = fetchedList
                .where(
                  (p) =>
                      p['status'] == 'REQUESTED' || p['status'] == 'INSPECTING',
                )
                .toList();

            // Sort finished jobs to the completed tab
            _completedPermits = fetchedList
                .where(
                  (p) => p['status'] == 'APPROVED' || p['status'] == 'DENIED',
                )
                .toList();

            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showInspectionDialog(Map<String, dynamic> permit) {
    bool isDamageFound = false;
    TextEditingController notesController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 24,
              right: 24,
              top: 24,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "ROOM INSPECTION",
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Permit #${permit['id'].toString().substring(0, 6)}",
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 24),

                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: SwitchListTile(
                      activeColor: Colors.redAccent,
                      title: Text(
                        "Is there room damage?",
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        "Selecting YES will deny the exit permit.",
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSecondary,
                          fontSize: 11,
                        ),
                      ),
                      value: isDamageFound,
                      onChanged: (val) =>
                          setModalState(() => isDamageFound = val),
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (isDamageFound)
                    TextField(
                      controller: notesController,
                      maxLines: 3,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      decoration: InputDecoration(
                        hintText: "Describe the damage...",
                        filled: true,
                        fillColor: Colors.redAccent.withOpacity(0.05),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Colors.redAccent.withOpacity(0.2),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Colors.redAccent,
                            width: 2,
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _submitInspection(
                          permit['id'].toString(),
                          isDamageFound,
                          notesController.text,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDamageFound
                            ? Colors.redAccent
                            : Colors.green.shade500,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        isDamageFound ? "DENY PERMIT" : "APPROVE PERMIT",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _submitInspection(
    String permitId,
    bool isDamage,
    String notes,
  ) async {
    try {
      final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();

      final payload = {
        "permit": permitId,
        "is_damage_found": isDamage,
        "damage_notes": notes.isEmpty ? "Room in good condition." : notes,
      };

      await http.post(
        Uri.parse('${ApiClass().getApiBaseUrl()}/room-inspections/'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      _fetchPermits(); // Refresh lists after action
    } catch (e) {
      debugPrint("Inspection failed");
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Wrapping the entire screen in a DefaultTabController
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
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
                        color: theme.colorScheme.primary,
                        letterSpacing: 2.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Exit Permits",
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: theme.colorScheme.onSurface,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),

              // Custom TabBar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: TabBar(
                    indicator: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: Colors.white,
                    unselectedLabelColor: theme.colorScheme.onSecondary,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      letterSpacing: 0.5,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                    dividerColor: Colors.transparent,
                    tabs: const [
                      Tab(text: "Pending"),
                      Tab(text: "Completed"),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Tab Views
              Expanded(
                child: _isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                          color: theme.colorScheme.primary,
                        ),
                      )
                    : TabBarView(
                        children: [
                          _buildPendingList(theme),
                          _buildCompletedList(theme),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- TAB 1: PENDING LIST ---
  Widget _buildPendingList(ThemeData theme) {
    if (_pendingPermits.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.checkmark_shield_fill,
              size: 64,
              color: theme.colorScheme.onSecondary.withOpacity(0.2),
            ),
            const SizedBox(height: 16),
            Text(
              "No pending inspections.",
              style: TextStyle(
                color: theme.colorScheme.onSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(left: 24, right: 24, bottom: 120),
      itemCount: _pendingPermits.length,
      itemBuilder: (context, index) {
        final p = _pendingPermits[index];
        final studentName = p['student_details']?['name'] ?? 'Student';
        final roomData =
            p['student_details']?['room_number_only'] ?? 'Unknown Room';
        final bool isAssignedToMe = p['status'] == 'INSPECTING';

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.03),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isAssignedToMe
                  ? Colors.purpleAccent.withOpacity(0.4)
                  : theme.colorScheme.primary.withOpacity(0.1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Room $roomData",
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isAssignedToMe
                          ? Colors.purple.withOpacity(0.15)
                          : Colors.orange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isAssignedToMe ? "DELEGATED TO YOU" : "OPEN REQUEST",
                      style: TextStyle(
                        color: isAssignedToMe ? Colors.purple : Colors.orange,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                "Requested by $studentName",
                style: TextStyle(
                  color: theme.colorScheme.onSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _showInspectionDialog(p),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isAssignedToMe
                        ? Colors.purple
                        : theme.colorScheme.primary,
                    side: BorderSide(
                      color: isAssignedToMe
                          ? Colors.purple.withOpacity(0.5)
                          : theme.colorScheme.primary.withOpacity(0.5),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    isAssignedToMe ? "START INSPECTION" : "CLAIM & INSPECT",
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- TAB 2: COMPLETED LIST ---
  Widget _buildCompletedList(ThemeData theme) {
    if (_completedPermits.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.doc_text_fill,
              size: 64,
              color: theme.colorScheme.onSecondary.withOpacity(0.2),
            ),
            const SizedBox(height: 16),
            Text(
              "No history found.",
              style: TextStyle(
                color: theme.colorScheme.onSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(left: 24, right: 24, bottom: 120),
      itemCount: _completedPermits.length,
      itemBuilder: (context, index) {
        final p = _completedPermits[index];
        final studentName = p['student_details']?['name'] ?? 'Student';
        final roomData =
            p['student_details']?['room_number_only'] ?? 'Unknown Room';
        final bool isApproved = p['status'] == 'APPROVED';

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: theme.colorScheme.onSecondary.withOpacity(0.1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Room $roomData",
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isApproved
                          ? Colors.green.withOpacity(0.15)
                          : Colors.redAccent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isApproved
                              ? CupertinoIcons.check_mark_circled_solid
                              : CupertinoIcons.xmark_circle_fill,
                          color: isApproved ? Colors.green : Colors.redAccent,
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isApproved ? "APPROVED" : "DENIED",
                          style: TextStyle(
                            color: isApproved ? Colors.green : Colors.redAccent,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                "Processed for $studentName",
                style: TextStyle(
                  color: theme.colorScheme.onSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
