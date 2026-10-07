import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../components/api_class.dart';
import '../../auth/login.dart';
import 'gate_passes_tab.dart';
import 'dashboard.dart';
import 'home_tab.dart';
import 'maintanance_tab.dart';
import 'medical_data.dart';
import 'notifications.dart';
import 'permits_tab.dart';
import 'applications_tab.dart';
import 'campus_map_tab.dart';
import 'report_emergency.dart';

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
  Timer? _statusCheckTimer;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _fetchUnreadCount();
    _checkMedicalProfileStatus();
  }

  @override
  void dispose() {
    _statusCheckTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkMedicalProfileStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final idToken = await user.getIdToken();

      final response = await http.get(
        Uri.parse('${ApiClass().getApiBaseUrl()}/medical-profiles/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data is List ? data : (data['results'] ?? []);

        if (results.isEmpty && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "CRITICAL: You must complete your Medical Profile for emergency dispatch.",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 5),
            ),
          );

          Navigator.push(
            context,
            CupertinoPageRoute(builder: (_) => const MedicalDataEntryScreen()),
          );
        }
      }
    } catch (e) {
      debugPrint("Failed to check medical profile status: $e");
    }
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString('user_data');
    if (userDataString != null) {
      setState(() {
        userData = jsonDecode(userDataString);
      });
    }
    _checkAssignmentStatus();
  }

  void _checkAssignmentStatus() {
    final bool isAssigned =
        userData?['room'] != null && userData?['landlord'] != null;

    if (!isAssigned) {
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

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_data', jsonEncode(newUserData));

          if (newlyAssigned) {
            _statusCheckTimer?.cancel();
          }
        }
      }
    } catch (e) {
      debugPrint("Live update check failed: $e");
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
    _statusCheckTimer?.cancel();
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
    final bool isCleared = userData?['verification_status'] ?? false;
    final bool isAssigned =
        userData?['room'] != null && userData?['landlord'] != null;

    String initials = "S";
    if (studentName.isNotEmpty && studentName != "Student ") {
      initials = studentName[0];
      if (surname.isNotEmpty) initials += surname[0];
    }

    // Build dynamic tabs
    List<NavItemData> activeTabs = [];

    if (!isAssigned) {
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

    activeTabs.add(
      NavItemData(
        icon: CupertinoIcons.bell_fill,
        label: 'Alerts',
        page: const Notifications(),
        badgeCount: _unreadCount,
      ),
    );

    if (isAssigned) {
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

    if (_selectedIndex >= activeTabs.length) {
      _selectedIndex = 0;
    }

    // Determine layout based on screen width
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    if (activeTabs.isEmpty) {
      return Scaffold(
        backgroundColor: bgColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      extendBody: !isDesktop, // Only extend body on mobile for floating nav bar
      body: isDesktop
          ? _buildDesktopLayout(
              activeTabs,
              studentName,
              studentNo,
              initials,
              primaryColor,
              slateColor,
              bgColor,
            )
          : _buildMobileLayout(activeTabs, primaryColor, slateColor, bgColor),
    );
  }

  // =========================================================================
  // DESKTOP & TABLET LAYOUT (PREMIUM SIDEBAR)
  // =========================================================================
  Widget _buildDesktopLayout(
    List<NavItemData> tabs,
    String name,
    String studentNo,
    String initials,
    Color primary,
    Color slate,
    Color bg,
  ) {
    return Row(
      children: [
        // Premium Sidebar
        Container(
          width: 280,
          decoration: BoxDecoration(
            color: bg.withOpacity(0.85),
            border: Border(
              right: BorderSide(color: primary.withOpacity(0.1), width: 1.5),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(5, 0),
              ),
            ],
          ),
          child: ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Column(
                children: [
                  // Profile Header
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 40,
                      horizontal: 20,
                    ),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: primary.withOpacity(0.15),
                          child: Text(
                            initials,
                            style: TextStyle(
                              color: primary,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          studentNo,
                          style: TextStyle(
                            fontSize: 13,
                            color: slate,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Navigation Links
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: tabs.length,
                      itemBuilder: (context, index) {
                        final tab = tabs[index];
                        final isSelected = _selectedIndex == index;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _selectedIndex = index;
                                if (tab.label == 'Alerts') _unreadCount = 0;
                              });
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 20,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? primary.withOpacity(0.1)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected
                                      ? primary.withOpacity(0.2)
                                      : Colors.transparent,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    tab.icon,
                                    color: isSelected ? primary : slate,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Text(
                                      tab.label,
                                      style: TextStyle(
                                        color: isSelected ? primary : slate,
                                        fontWeight: isSelected
                                            ? FontWeight.w800
                                            : FontWeight.w600,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                  if (tab.badgeCount > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.redAccent,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        tab.badgeCount > 9
                                            ? '9+'
                                            : tab.badgeCount.toString(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Sidebar Actions (Map, Emergency, Logout)
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        _buildDesktopActionButton(
                          icon: CupertinoIcons.map_fill,
                          label: "Campus Map",
                          color: primary,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CampusMapTab(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildDesktopActionButton(
                          icon: Icons.emergency,
                          label: "Report Emergency",
                          color: Colors.redAccent,
                          onTap: () => Navigator.push(
                            context,
                            CupertinoPageRoute(
                              builder: (_) => const EmergencyReportingScreen(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextButton.icon(
                          onPressed: _handleLogout,
                          icon: const Icon(
                            CupertinoIcons.power,
                            color: Colors.grey,
                          ),
                          label: const Text(
                            "Log Out",
                            style: TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Main Content Area
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: tabs[_selectedIndex].page,
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // MOBILE LAYOUT (FLOATING NAVBAR & FABs)
  // =========================================================================
  Widget _buildMobileLayout(
    List<NavItemData> tabs,
    Color primary,
    Color slate,
    Color bg,
  ) {
    return Stack(
      children: [
        // Main Content
        tabs[_selectedIndex].page,

        // Floating Action Buttons (Positioned above the bottom nav)
        Positioned(
          right: 16,
          bottom: 110, // Avoids overlapping with the 72px tall bottom nav
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton(
                heroTag: "campusMapBtn",
                backgroundColor: primary,
                elevation: 6,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CampusMapTab()),
                ),
                child: const Icon(CupertinoIcons.map_fill, color: Colors.white),
              ),
              const SizedBox(height: 16),
              FloatingActionButton(
                heroTag: "emergencyBtn",
                backgroundColor: Colors.redAccent,
                elevation: 6,
                onPressed: () => Navigator.push(
                  context,
                  CupertinoPageRoute(
                    builder: (_) => const EmergencyReportingScreen(),
                  ),
                ),
                child: const Icon(Icons.emergency, color: Colors.white),
              ),
            ],
          ),
        ),

        // Premium Bottom Navigation Bar
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(
              left: 20.0,
              right: 20.0,
              bottom: 24.0,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  height: 72,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: bg.withOpacity(0.75),
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
                    children: List.generate(tabs.length, (index) {
                      final tab = tabs[index];
                      return _buildMobileNavItem(
                        index,
                        tab.icon,
                        tab.label,
                        primary,
                        slate,
                        badgeCount: tab.badgeCount,
                        onTap: () {
                          setState(() {
                            _selectedIndex = index;
                            if (tab.label == 'Alerts') _unreadCount = 0;
                          });
                        },
                      );
                    }),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileNavItem(
    int index,
    IconData icon,
    String label,
    Color primary,
    Color slate, {
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
          color: isSelected ? primary.withOpacity(0.15) : Colors.transparent,
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
                  color: isSelected ? primary : slate.withOpacity(0.4),
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
                          fontSize: 10,
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
                      color: primary,
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
