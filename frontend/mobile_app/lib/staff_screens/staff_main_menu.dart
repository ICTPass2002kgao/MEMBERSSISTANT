import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_app/components/api_class.dart';
import 'package:mobile_app/auth/login.dart';
import 'package:mobile_app/staff_screens/notifications.dart';
import 'package:mobile_app/student_screens/tabs/campus_map_tab.dart'; // Reusing map for staff
import 'package:mobile_app/staff_screens/staff_emergency_dashboard.dart'; 
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

class StaffMainMenu extends StatefulWidget {
  const StaffMainMenu({super.key});

  @override
  State<StaffMainMenu> createState() => _StaffMainMenuState();
}

class _StaffMainMenuState extends State<StaffMainMenu> {
  Map<String, dynamic>? userData;
  int _selectedIndex = 0;
  int _unreadCount = 0;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _fetchUnreadCount();
    
    // Poll for new emergency notifications every 15 seconds
    _pollingTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      _fetchUnreadCount();
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
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
    _pollingTimer?.cancel();
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

    // Build tabs for Staff
    List<NavItemData> activeTabs = [
      NavItemData(
        icon: CupertinoIcons.shield_lefthalf_fill,
        label: 'Dispatch',
        page: const StaffEmergencyDashboard(),
      ),
      NavItemData(
        icon: CupertinoIcons.map_fill,
        label: 'Map',
        page: const CampusMapTab(), // Reusing the Mapbox tab for staff navigation
      ),
      NavItemData(
        icon: CupertinoIcons.bell_fill,
        label: 'Alerts',
        page: const StaffNotifications(),
        badgeCount: _unreadCount,
      ),
      NavItemData(
        icon: CupertinoIcons.person_fill,
        label: 'Profile',
        page: _StaffProfileTab(userData: userData, onLogout: _handleLogout),
      ),
    ];

    return Scaffold(
      backgroundColor: bgColor,
      extendBody: true,
      body: activeTabs[_selectedIndex].page,
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
                  // If it's the dispatch tab, let's make it red to stand out for emergencies
                  final isEmergencyTab = tab.label == 'Dispatch';
                  final tabColor = isEmergencyTab ? Colors.redAccent : primaryColor;

                  return _buildNavItem(
                    index,
                    tab.icon,
                    tab.label,
                    tabColor,
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
    Color activeColor,
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
          color: isSelected ? activeColor.withOpacity(0.15) : Colors.transparent,
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
                  color: isSelected ? activeColor : slateColor.withOpacity(0.4),
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
                      color: activeColor,
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

// ============================================================================
// STAFF PROFILE TAB (Built-in)
// ============================================================================
class _StaffProfileTab extends StatelessWidget {
  final Map<String, dynamic>? userData;
  final VoidCallback onLogout;

  const _StaffProfileTab({required this.userData, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final textColor = theme.colorScheme.onSurface;
    final slateColor = theme.colorScheme.onSecondary;

    final String name = "${userData?['name'] ?? 'Staff'} ${userData?['surname'] ?? ''}".trim();
    final String role = userData?['role'] ?? 'STAFF MEMBER';
    final String email = userData?['email'] ?? 'No email provided';
    final String phone = userData?['phone'] ?? 'N/A';
    
    String initials = "S";
    if (name.isNotEmpty) {
      initials = name[0];
      if (userData?['surname'] != null && userData!['surname'].isNotEmpty) {
        initials += userData!['surname'][0];
      }
    }

    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(left: 24, right: 24, top: 32, bottom: 100),
        child: Column(
          children: [
            Text(
              "STAFF PROFILE",
              style: TextStyle(
                color: primaryColor,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 32),
            
            // Avatar Header
            Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: primaryColor.withOpacity(0.3), width: 2),
                    ),
                    child: CircleAvatar(
                      radius: 48,
                      backgroundColor: primaryColor.withOpacity(0.15),
                      backgroundImage: userData?['face_url'] != null ? NetworkImage(userData!['face_url']) : null,
                      child: userData?['face_url'] == null
                          ? Text(
                              initials.toUpperCase(),
                              style: TextStyle(color: primaryColor, fontWeight: FontWeight.w900, fontSize: 36),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    name,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: textColor),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      role,
                      style: TextStyle(color: primaryColor, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1.0),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // Information Block
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "CONTACT INFORMATION",
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: primaryColor, letterSpacing: 1.5),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.02),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: primaryColor.withOpacity(0.1)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Icon(CupertinoIcons.mail_solid, color: slateColor.withOpacity(0.5), size: 22),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Email Address", style: TextStyle(color: slateColor, fontSize: 11, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 2),
                              Text(email, style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, thickness: 1, color: primaryColor.withOpacity(0.05), indent: 56),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Icon(CupertinoIcons.phone_fill, color: slateColor.withOpacity(0.5), size: 22),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Phone Number", style: TextStyle(color: slateColor, fontSize: 11, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 2),
                              Text(phone, style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // Logout Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: onLogout,
                icon: const Icon(CupertinoIcons.square_arrow_right),
                label: const Text('SIGN OUT SECURELY', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.withOpacity(0.1),
                  foregroundColor: Colors.redAccent,
                  elevation: 0,
                  side: BorderSide(color: Colors.red.withOpacity(0.3)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}