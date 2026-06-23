import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_app/components/face_cache_service.dart';
import 'package:mobile_app/student_screens/tabs/profile.dart';
import 'package:mobile_app/components/api_class.dart';

class Dashboard extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String name;
  final String studentNo;
  final String initials;
  final bool isCleared;
  final String accommodationName;
  final String roomNumber;
  final String blockName;
  final String unitName;
  final Function(int) onNavigate;
  final VoidCallback onLogout;

  const Dashboard({
    super.key,
    required this.userData,
    required this.name,
    required this.studentNo,
    required this.initials,
    required this.isCleared,
    required this.accommodationName,
    required this.roomNumber,
    required this.blockName,
    required this.unitName,
    required this.onNavigate,
    required this.onLogout,
  });

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  int _selectedTab = 0;

  // Stores the raw decrypted image bytes
  Uint8List? _decryptedFaceBytes;
  bool _isLoadingFace = false;

  @override
  void initState() {
    super.initState();
    _fetchDecryptedFace();
  }
Future<void> _fetchDecryptedFace() async {
    final String? faceUrl = widget.userData['face_url'];
    final studentId = widget.userData['id']?.toString(); 
    
    if (faceUrl == null || faceUrl.isEmpty || studentId == null) return;

    // 1. CHECK THE CACHE FIRST
    final cachedFace = FaceCacheService().getFace(studentId);
    if (cachedFace != null) {
      if (mounted) {
        setState(() {
          _decryptedFaceBytes = cachedFace;
          _isLoadingFace = false;
        });
      }
      return; // Stop here, no need to hit the backend!
    }

    // 2. IF NOT CACHED, FETCH FROM BACKEND
    if (mounted) setState(() => _isLoadingFace = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final token = await user.getIdToken();
        if (token != null) {
          final baseUrl = ApiClass().getApiBaseUrl();
          final url = Uri.parse('$baseUrl/students/$studentId/decrypted-face/');

          final response = await http.get(
            url,
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          );

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            final String? base64String = data['face_base64'];

            if (base64String != null && base64String.isNotEmpty) {
              final decodedBytes = base64Decode(base64String);
              
              // 3. SAVE TO CACHE FOR NEXT TIME
              FaceCacheService().saveFace(studentId, decodedBytes);

              if (mounted) {
                setState(() {
                  _decryptedFaceBytes = decodedBytes;
                });
              }
            }
          } else {
            debugPrint('Failed to decrypt face: ${response.statusCode}');
          }
        }
      }
    } catch (e) {
      debugPrint("Error loading decrypted face: $e");
    } finally {
      if (mounted) setState(() => _isLoadingFace = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return SafeArea(
      child: Column(
        children: [
          // --- CUSTOM TOP TAB BAR ---
          Container(
            margin: const EdgeInsets.only(left: 24, right: 24, top: 16),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildTabButton(
                    title: "My Details",
                    index: 0,
                    primaryColor: primaryColor,
                  ),
                ),
                Expanded(
                  child: _buildTabButton(
                    title: "Student Card",
                    index: 1,
                    primaryColor: primaryColor,
                  ),
                ),
              ],
            ),
          ),

          // --- TAB CONTENT ---
          Expanded(
            child: _selectedTab == 0
                ? _buildMyDetails(context)
                : _buildStudentCardView(context),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required String title,
    required int index,
    required Color primaryColor,
  }) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTab = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : primaryColor.withOpacity(0.5),
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // MY DETAILS TAB
  // ===========================================================================
  Widget _buildMyDetails(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final slateColor = theme.colorScheme.onSecondary;
    final textColor = theme.colorScheme.onSurface;

    final String? accommodationLogoUrl =
        widget.userData['accommodation_logo_url'];

    final bool hasUnit =
        widget.unitName != "Unassigned Unit" && widget.unitName.isNotEmpty;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- HEADER ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Good day,',
                      style: TextStyle(
                        color: slateColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.name,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: textColor,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      CupertinoPageRoute(
                        builder: (context) => StudentProfileScreen(
                          userData: widget.userData,
                          onLogout: widget.onLogout,
                          initials: widget.initials,
                        ),
                      ),
                    );
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
                      // Use MemoryImage if bytes exist, otherwise null
                      backgroundImage: _decryptedFaceBytes != null
                          ? MemoryImage(_decryptedFaceBytes!)
                          : null,
                      child: _decryptedFaceBytes == null
                          ? _isLoadingFace
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    widget.initials.toUpperCase(),
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
            const SizedBox(height: 32),

            // --- HERO CLEARANCE CARD ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.03),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: primaryColor.withOpacity(0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildTag("ID: ${widget.studentNo}", primaryColor),
                      Icon(
                        CupertinoIcons.shield_lefthalf_fill,
                        color: primaryColor.withOpacity(0.3),
                        size: 24,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'The verification happens in monthly basis',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: slateColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: widget.userData['isVerified'] == true
                              ? Colors.green.withOpacity(0.15)
                              : Colors.red.withOpacity(0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: widget.userData['isVerified'] == true
                                ? Colors.green.withOpacity(0.3)
                                : Colors.red.withOpacity(0.3),
                          ),
                        ),
                        child: Icon(
                          widget.userData['isVerified'] == true
                              ? CupertinoIcons.checkmark_alt
                              : CupertinoIcons.clear,
                          color: widget.userData['isVerified'] == true
                              ? Colors.green.shade400
                              : Colors.red.shade400,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        widget.userData['isVerified'] == true
                            ? 'GRANTED'
                            : 'NOT VERIFIED',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: widget.userData['isVerified'] == true
                              ? Colors.green.shade400
                              : Colors.red.shade400,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // --- PREMIUM RESIDENCE DETAILS CARD ---
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: textColor.withOpacity(0.02),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: primaryColor.withOpacity(0.05)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          clipBehavior: Clip.hardEdge,
                          child:
                              accommodationLogoUrl != null &&
                                  accommodationLogoUrl.isNotEmpty
                              ? Image.network(
                                  accommodationLogoUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Icon(
                                        CupertinoIcons.house_alt_fill,
                                        color: primaryColor,
                                        size: 22,
                                      ),
                                )
                              : Icon(
                                  CupertinoIcons.house_alt_fill,
                                  color: primaryColor,
                                  size: 22,
                                ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "REGISTERED ACCOMMODATION",
                                style: TextStyle(
                                  color: slateColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.accommodationName.toUpperCase(),
                                style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: primaryColor.withOpacity(0.05),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 16.0,
                      right: 16.0,
                      top: 20.0,
                      bottom: 20.0,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildResidentInfoTile(
                            "BLOCK",
                            widget.blockName,
                            primaryColor,
                            slateColor,
                            textColor,
                          ),
                        ),
                        if (hasUnit) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildResidentInfoTile(
                              "UNIT",
                              widget.unitName,
                              primaryColor,
                              slateColor,
                              textColor,
                            ),
                          ),
                        ],
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildResidentInfoTile(
                            "ROOM",
                            widget.roomNumber,
                            primaryColor,
                            slateColor,
                            textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // STUDENT CARD TAB
  // ===========================================================================
  Widget _buildStudentCardView(BuildContext context) {
    final String email = "${widget.studentNo}@edu.vut.ac.za";
    final String course = "N DIP: INFORMATION TECHNOLOGY";

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Center(
              child: Container(
                alignment: Alignment.center,
                width: double.infinity,
                height: 230,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    tileMode: TileMode.mirror,
                    colors: [
                      Color(0xFF1E2A40),
                      Color.fromARGB(255, 176, 136, 26),
                    ],
                    stops: [0.4, 1.3],
                    transform: GradientRotation(0.3),
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Opacity(
                        opacity: 0.05,
                        child: Image.network(
                          'https://www.transparenttextures.com/patterns/scratched-surface.png',
                          repeat: ImageRepeat.repeat,
                          errorBuilder: (context, error, stackTrace) =>
                              const SizedBox(),
                        ),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Image.asset(
                                'assets/vut_logo.PNG',
                                height: 80,
                                fit: BoxFit.contain,
                                alignment: Alignment.topLeft,
                              ),
                              Text(
                                'maVuti',
                                style: TextStyle(
                                  fontFamily: 'Trebuchet',
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.name.toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      course,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 7.5,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      email,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      height: 32,
                                      width: 180,
                                      color: Colors.white.withOpacity(0.8),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 2,
                                      ),
                                      child: BarcodeWidget(
                                        barcode: Barcode.code128(),
                                        data: widget.studentNo,
                                        drawText: false,
                                        color: Colors.black,
                                        backgroundColor: Colors.transparent,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                width: 100,
                                height: 125,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.5),
                                    width: 1,
                                  ),
                                ),
                                child: _decryptedFaceBytes != null
                                    ? Image.memory(
                                        _decryptedFaceBytes!,
                                        height: 200,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                Container(
                                                  color: Colors.grey.shade300,
                                                  child: const Icon(
                                                    CupertinoIcons.person_fill,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                      )
                                    : Container(
                                        color: Colors.grey.shade300,
                                        child: _isLoadingFace
                                            ? const Center(
                                                child:
                                                    CupertinoActivityIndicator(),
                                              )
                                            : const Icon(
                                                CupertinoIcons.person_fill,
                                                color: Colors.grey,
                                              ),
                                      ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "Digital Student Card",
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // HELPER WIDGETS
  // ===========================================================================
  Widget _buildResidentInfoTile(
    String label,
    String value,
    Color primary,
    Color slate,
    Color text,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 4.0),
      decoration: BoxDecoration(
        color: primary.withOpacity(0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primary.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              color: slate,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: text,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String text, Color primary) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: primary.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primary.withOpacity(0.2)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: primary,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}
