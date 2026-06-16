import 'dart:convert';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_app/components/api_class.dart';
import 'package:mobile_app/auth/login.dart';
import 'package:mobile_app/student_screens/tabs/dashboard.dart';
import 'package:mobile_app/student_screens/tabs/profile.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'accommodation_details.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  List<dynamic> _accommodations = [];
  bool _isLoading = true;
  String _errorMessage = '';

  Map<String, dynamic>? _userData;
  String _initials = "S";

  @override
  void initState() {
    super.initState();
    _fetchAccommodations();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString('user_data');
    if (userDataString != null) {
      final data = jsonDecode(userDataString);
      if (mounted) {
        setState(() {
          _userData = data;
          String name = data['name'] ?? 'Student';
          String surname = data['surname'] ?? '';
          if (name.isNotEmpty && name != "Student ") {
            _initials = name[0];
            if (surname.isNotEmpty) _initials += surname[0];
          }
        });
      }
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

  Future<void> _fetchAccommodations() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiClass().getApiBaseUrl()}/accommodations/'),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final decodedResponse = jsonDecode(response.body);

        setState(() {
          if (decodedResponse is Map<String, dynamic> &&
              decodedResponse.containsKey('results')) {
            _accommodations = decodedResponse['results'];
          } else if (decodedResponse is List) {
            _accommodations = decodedResponse;
          } else {
            _accommodations = [];
          }
          _isLoading = false;
        });
      } else {
        throw Exception(
          'Failed to load accommodations. Status: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint("Fetch Accommodations Error: $e");
      if (mounted) {
        setState(() {
          _errorMessage =
              'Could not connect to the server. Please try again later.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    final String? faceUrl = _userData?['face_url']?.toString();
    final bool hasFace = faceUrl != null && faceUrl.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Discover',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: theme.colorScheme.onSurface,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text(
                        'Premium Student Residences',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: primaryColor,
                          letterSpacing: 1.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    if (_userData != null) {
                      Navigator.push(
                        context,
                        CupertinoPageRoute(
                          builder: (context) => StudentProfileScreen(
                            userData: _userData!,
                            onLogout: _handleLogout,
                            initials: _initials,
                          ),
                        ),
                      );
                    } else {
                      Navigator.pushReplacementNamed(context, '/');
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: primaryColor.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 24,
                      backgroundColor: primaryColor.withOpacity(0.15),
                      backgroundImage: hasFace ? NetworkImage(faceUrl) : null,
                      child: !hasFace
                          ? Text(
                              _initials.toUpperCase(),
                              style: TextStyle(
                                color: primaryColor,
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: primaryColor))
                : _errorMessage.isNotEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text(
                        _errorMessage,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.redAccent.shade400),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 24, top: 8),
                    itemCount: _accommodations.length,
                    itemBuilder: (context, index) {
                      final acc = _accommodations[index];
                      return _buildAccommodationCard(context, acc);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccommodationCard(
    BuildContext context,
    Map<dynamic, dynamic> acc,
  ) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final imageUrl =
        acc['accommodation_logo_url'] ??
        'https://images.unsplash.com/photo-1555854877-bab0e564b8d5?q=80&w=1000&auto=format&fit=crop';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AccommodationDetailsScreen(accommodation: acc),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        height: 220,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            Hero(
              tag: 'acc_image_${acc['id']}',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: Image.network(
                  imageUrl,
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      Container(color: Colors.grey.shade300),
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                ),
              ),
            ),
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                acc['name'] ?? 'Residence',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    color: primaryColor,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      acc['address'] ?? 'Address unlisted',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.8),
                                        fontSize: 12,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: primaryColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            acc['gender_target'] ?? 'MIXED',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ],
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
