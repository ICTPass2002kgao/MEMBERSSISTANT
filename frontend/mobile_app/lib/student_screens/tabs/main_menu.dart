import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_app/components/api_class.dart';
import 'package:mobile_app/auth/login.dart';
import 'package:mobile_app/student_screens/tabs/gate_passes_tab.dart';
import 'package:mobile_app/student_screens/tabs/dashboard.dart';
import 'package:mobile_app/student_screens/tabs/home_tab.dart';
import 'package:mobile_app/student_screens/tabs/maintanance_tab.dart';
import 'package:mobile_app/student_screens/tabs/notifications.dart';
import 'package:mobile_app/student_screens/tabs/permits_tab.dart';
import 'package:mobile_app/student_screens/tabs/applications_tab.dart';
import 'package:mobile_app/student_screens/tabs/campus_map_tab.dart'; 
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Helper class to manage dynamic tabs
class NavItemData {
  final IconData icon;
  final String label;
  final Widget page;
  final int badgeCount;

  NavItemData({
    required this.icon,
    required this.label,
    required this.page,
    this.badgeCount = 0,
  });
}

class StudentMainMenu extends StatefulWidget {
  const StudentMainMenu({super.key});

  @override
  State<StudentMainMenu> createState() => _StudentMainMenuState();
}

class _StudentMainMenuState extends State<StudentMainMenu> {
  Map<String, dynamic>? userData;
  int _selectedIndex = 0;
  int _unreadCount = 0;
  Timer? _statusCheckTimer; // Timer for live background updates

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _fetchUnreadCount();
  }

  @override
  void dispose() {
    _statusCheckTimer?.cancel(); // Prevent memory leaks when navigating away
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString('user_data');
    if (userDataString != null) {
      setState(() {
        userData = jsonDecode(userDataString);
      });
    }

    // After initial load, start smart polling if they are not assigned yet
    _checkAssignmentStatus();
  }

  // --- SMART LIVE UPDATE LOGIC ---
  void _checkAssignmentStatus() {
    final bool isAssigned =
        userData?['room'] != null && userData?['landlord'] != null;

    if (!isAssigned) {
      // If unassigned, check the backend every 10 seconds for placement updates
      _statusCheckTimer = Timer.periodic(const Duration(seconds: 10), (
        timer,
      ) async {
        await _fetchLatestProfile();
      });
    }
  }

  Future<void> _fetchLatestProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final idToken = await user.getIdToken();

      final response = await http.get(
        Uri.parse('${ApiClass().getApiBaseUrl()}/students/me/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );

      if (response.statusCode == 200) {
        final newUserData = jsonDecode(response.body);

        final bool newlyAssigned =
            newUserData['room'] != null && newUserData['landlord'] != null;

        if (mounted) {
          setState(() {
            userData = newUserData;
          });

          // Save the fresh data locally
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_data', jsonEncode(newUserData));

          // If they just got placed, kill the timer so it doesn't waste network
          if (newlyAssigned) {
            _statusCheckTimer?.cancel();
          }
        }
      }
    } catch (e) {
      debugPrint("Live update check failed: $e");
    }
  }
  // -------------------------------

  Future<void> _fetchUnreadCount() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final idToken = await user.getIdToken();

      final response = await http.get(
        Uri.parse('${ApiClass().getApiBaseUrl()}/notifications/?is_read=false'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data is List ? data : (data['results'] ?? []);
        if (mounted) {
          setState(() {
            _unreadCount = results.length;
          });
        }
      }
    } catch (e) {
      debugPrint("Failed to fetch unread count: $e");
    }
  }

  Future<void> _handleLogout() async {
    _statusCheckTimer?.cancel(); // Stop timer on logout
    await FirebaseAuth.instance.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final bgColor = theme.scaffoldBackgroundColor;
    final slateColor = theme.colorScheme.onSecondary;

    final String studentName =
        "${userData?['name'] ?? 'Student'} ${userData?['surname'] ?? ''}";
    final String surname = userData?['surname'] ?? '';
    final String studentNo = userData?['student_number'] ?? 'Unknown ID';
    final bool isCleared = userData?['is_cleared_for_exit'] ?? false;

    // Trigger for the UI rendering dynamically
    final bool isAssigned =
        userData?['room'] != null && userData?['landlord'] != null;

    String initials = "S";
    if (studentName.isNotEmpty && studentName != "Student ") {
      initials = studentName[0];
      if (surname.isNotEmpty) initials += surname[0];
    }

    // Dynamically build the tabs based on real-time assignment status
    List<NavItemData> activeTabs = [];

    if (!isAssigned) {
      // Unassigned Student: Exclude Dashboard and operational tabs
      activeTabs.add(
        NavItemData(
          icon: CupertinoIcons.home,
          label: 'Home',
          page: const HomeTab(),
        ),
      );
      activeTabs.add(
        NavItemData(
          icon: CupertinoIcons.list_bullet,
          label: 'Applications',
          page: const ApplicationsTab(),
        ),
      );
    } else {
      // Assigned Student: Exclude Home, Include Dashboard and operations
      activeTabs.add(
        NavItemData(
          icon: CupertinoIcons.square_grid_2x2_fill,
          label: 'Dashboard',
          page: Dashboard(
            unitName: userData?['unit_name'] ?? 'Unknown Unit',
            userData: userData ?? {},
            name: studentName,
            studentNo: studentNo,
            initials: initials,
            isCleared: isCleared,
            onNavigate: (index) => setState(() => _selectedIndex = index),
            onLogout: _handleLogout,
            accommodationName:
                userData?['accommodation_name'] ?? 'Pending Assignment',
            blockName: userData?['block_name'] ?? 'Pending',
            roomNumber: userData?['room_number_only'] ?? 'Pending',
          ),
        ),
      );
      activeTabs.add(
        NavItemData(
          icon: CupertinoIcons.wrench_fill,
          label: 'Fixes',
          page: const MaintenanceTab(),
        ),
      );
    }

    // GLOBAL TABS FOR ALL STUDENTS (Assigned and Unassigned)
    activeTabs.add(
      NavItemData(
        icon: CupertinoIcons.map_fill,
        label: 'Campus',
        page: const CampusMapTab(),
      ),
    );

    activeTabs.add(
      NavItemData(
        icon: CupertinoIcons.bell_fill,
        label: 'Alerts',
        page: const Notifications(),
        badgeCount: _unreadCount,
      ),
    );

    if (isAssigned) {
      // Add the remaining operational tabs for assigned students
      activeTabs.add(
        NavItemData(
          icon: CupertinoIcons.doc_text_fill,
          label: 'Gate Passes',
          page: const GatePassesTab(),
        ),
      );
      activeTabs.add(
        NavItemData(
          icon: CupertinoIcons.doc_text_fill,
          label: 'Permits',
          page: const PermitsTab(),
        ),
      );
    }

    // Safety check in case the assignment status changes and the index goes out of bounds
    if (_selectedIndex >= activeTabs.length) {
      _selectedIndex = 0;
    }

    return Scaffold(
      backgroundColor: bgColor,
      extendBody: true,
       body: activeTabs.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : activeTabs[_selectedIndex].page,
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 32.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              height: 72,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: bgColor.withOpacity(0.75),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: Colors.white.withOpacity(0.08),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(activeTabs.length, (index) {
                  final tab = activeTabs[index];
                  return _buildNavItem(
                    index,
                    tab.icon,
                    tab.label,
                    primaryColor,
                    slateColor,
                    badgeCount: tab.badgeCount,
                    onTap: () {
                      setState(() {
                        _selectedIndex = index;
                        if (tab.label == 'Alerts') {
                          _unreadCount = 0;
                        }
                      });
                    },
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData icon,
    String label,
    Color primaryColor,
    Color slateColor, {
    int badgeCount = 0,
    required VoidCallback onTap,
  }) {
    final bool isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutQuint,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 20.0 : 12.0,
          vertical: 12.0,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  color: isSelected
                      ? primaryColor
                      : slateColor.withOpacity(0.4),
                  size: 24,
                ),
                if (badgeCount > 0)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        badgeCount > 9 ? '9+' : badgeCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutQuint,
              child: SizedBox(
                width: isSelected ? null : 0,
                child: Padding(
                  padding: EdgeInsets.only(left: isSelected ? 8.0 : 0),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      letterSpacing: 0.5,
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
}