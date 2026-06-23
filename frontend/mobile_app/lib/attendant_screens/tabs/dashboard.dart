import 'dart:convert';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_app/components/api_class.dart';
import 'package:mobile_app/attendant_screens/tabs/attend_permit.dart';
import 'package:mobile_app/attendant_screens/tabs/home_tab.dart';
import 'package:mobile_app/attendant_screens/tabs/notifications.dart';
import 'package:mobile_app/attendant_screens/tabs/verification_tab.dart';
import 'package:mobile_app/auth/login.dart';
import 'package:mobile_app/student_screens/tabs/campus_map_tab.dart';
import 'package:mobile_app/student_screens/tabs/report_emergency.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AttendantDashboard extends StatefulWidget {
  const AttendantDashboard({super.key});

  @override
  State<AttendantDashboard> createState() => _AttendantDashboardState();
}

class _AttendantDashboardState extends State<AttendantDashboard> {
  Map<String, dynamic>? userData;
  int _selectedIndex = 0;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _fetchUnreadCount();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString('user_data');
    if (userDataString != null) {
      setState(() {
        userData = jsonDecode(userDataString);
      });
    }
  }

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
        if (mounted) setState(() => _unreadCount = results.length);
      }
    } catch (e) {
      debugPrint("Failed to fetch unread count");
    }
  }

  Future<void> _handleLogout() async {
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

    final String staffName = userData?['name'] ?? 'Staff';
    final String surname = userData?['surname'] ?? '';
    final String role = userData?['role'] ?? 'ATTENDANT';

    String initials = "A";
    if (staffName.isNotEmpty) {
      initials = staffName[0];
      if (surname.isNotEmpty) initials += surname[0];
    }

    final List<Widget> pages = [
      AttendantHomeTab(
        name: staffName,
        role: role,
        initials: initials,
        onNavigate: (index) => setState(() => _selectedIndex = index),
        onLogout: _handleLogout,
      ),
      const AttendantPermitsTab(),
      const AttendantNotifications(),
      const AttendantVerificationTab(),
    ];

    return Scaffold(
      backgroundColor: bgColor,
      extendBody: true,
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: FloatingActionButton(
              heroTag:
                  "campusMapBtn", // Unique tag required when using multiple FABs
              backgroundColor: primaryColor,
              elevation: 6,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CampusMapTab()),
                );
              },
              child: const Icon(CupertinoIcons.map_fill, color: Colors.white),
            ),
          ),
          const SizedBox(height: 16), // Spacing between the buttons
          FloatingActionButton(
            heroTag:
                "emergencyBtn", // Unique tag required when using multiple FABs
            backgroundColor: Colors.redAccent,
            elevation: 6,
            onPressed: () {
              Navigator.push(
                context,
                CupertinoPageRoute(
                  builder: (context) => const EmergencyReportingScreen(),
                ),
              );
            },
            child: const Icon(Icons.emergency, color: Colors.white),
          ),
        ],
      ),

      body: SafeArea(bottom: false, child: pages[_selectedIndex]),
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
                children: [
                  _buildNavItem(
                    0,
                    CupertinoIcons.square_grid_2x2_fill,
                    'Home',
                    primaryColor,
                    slateColor,
                  ),
                  _buildNavItem(
                    1,
                    CupertinoIcons.doc_checkmark_fill,
                    'Permits',
                    primaryColor,
                    slateColor,
                  ),
                  _buildNavItem(
                    2,
                    CupertinoIcons.bell_fill,
                    'Alerts',
                    primaryColor,
                    slateColor,
                    badgeCount: _unreadCount,
                  ),
                  _buildNavItem(
                    3,
                    CupertinoIcons.doc_text_fill,
                    'Verification',
                    primaryColor,
                    slateColor,
                  ),
                ],
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
  }) {
    final bool isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedIndex = index;
          if (index == 3) _unreadCount = 0;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutQuint,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 16.0 : 10.0,
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
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        badgeCount > 9 ? '9+' : badgeCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
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
                      fontSize: 11,
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
