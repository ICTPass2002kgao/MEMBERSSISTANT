import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:mobile_app/components/api_class.dart';
import 'package:mobile_app/components/face_cache_service.dart';
import 'package:mobile_app/student_screens/tabs/medical_data.dart';

class StudentProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  final VoidCallback onLogout;
  final String initials;

  const StudentProfileScreen({
    super.key,
    required this.userData,
    required this.onLogout,
    required this.initials,
  });

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  Uint8List? _decryptedFaceBytes;
  bool _isLoadingFace = false;

  @override
  void initState() {
    super.initState();
    _fetchDecryptedFace();
  }

  Future<void> _fetchDecryptedFace() async {
    final String? faceUrl = widget.userData['face_url']?.toString();
    final studentId = widget.userData['id']?.toString();

    if (faceUrl == null || faceUrl.trim().isEmpty || studentId == null) return;

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

  Future<void> _resetPassword(BuildContext context, String email) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      if (!context.mounted) return;
      Navigator.pop(context); // close loader

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Password reset email sent to $email"),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context); // close loader
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Failed to send reset email. Please try again."),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  // Mandatory iOS App Store compliance functionality to process account purges
  Future<void> _deleteAccountWorkflow() async {
    final studentId = widget.userData['id']?.toString();
    if (studentId == null) return;

    bool confirmDelete = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text(
              "Delete Account",
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent),
            ),
            content: const Text(
              "Are you completely sure you want to permanently purge your account? "
              "This choice is irreversible and will erase your student profile, securely encrypted biometric records, and legal files from the platform system infrastructure.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                child: const Text("DELETE PERMANENTLY"),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmDelete) return;

    if (mounted) setState(() => _isLoadingFace = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final token = await user.getIdToken();
        if (token != null) {
          final baseUrl = ApiClass().getApiBaseUrl();
          final url = Uri.parse('$baseUrl/students/$studentId/');

          // Hits your Django destroy method which deletes Firebase user and SQL records atomically
          final response = await http.delete(
            url,
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          );

          if (response.statusCode == 200 || response.statusCode == 204) {
            FaceCacheService().clearCache();
            try {
              await user.delete();
            } catch (_) {
              // Session might already be invalidated by the backend execution loop
            }
            widget.onLogout();
            if (mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Account successfully deleted."),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } else {
            throw Exception('Backend rejection execution error.');
          }
        }
      }
    } catch (e) {
      debugPrint("Error running account destruction pipeline: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Security protocol error. Re-authenticate or contact system administrators."),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingFace = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final slateColor = theme.colorScheme.onSecondary;
    final textColor = theme.colorScheme.onSurface;

    final String nameStr =
        "${widget.userData['name']?.toString() ?? ''} ${widget.userData['surname']?.toString() ?? ''}"
            .trim();
    final String name = nameStr.isNotEmpty ? nameStr : 'Student';

    final String email =
        widget.userData['email']?.toString() ?? 'No email provided';
    final String studentNo =
        widget.userData['student_number']?.toString() ?? 'Unknown ID';
    final String phone = widget.userData['phone']?.toString() ?? 'N/A';
    final String accName =
        widget.userData['accommodation_name']?.toString() ?? 'Unassigned';
    final String blockName =
        widget.userData['block_name']?.toString() ?? 'Unassigned';
    final String roomNum =
        widget.userData['room_number_only']?.toString() ?? 'Unassigned';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(CupertinoIcons.back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "MY PROFILE",
          style: TextStyle(
            color: primaryColor,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(left: 24, right: 24, bottom: 60),
        child: Column(
          children: [
            const SizedBox(height: 16),
            // Avatar Header
            Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: primaryColor.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 48,
                      backgroundColor: primaryColor.withOpacity(0.15),
                      backgroundImage: _decryptedFaceBytes != null
                          ? MemoryImage(_decryptedFaceBytes!)
                          : null,
                      child: _decryptedFaceBytes == null
                          ? _isLoadingFace
                                ? const CircularProgressIndicator()
                                : Text(
                                    widget.initials.toUpperCase(),
                                    style: TextStyle(
                                      color: primaryColor,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 36,
                                    ),
                                  )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    studentNo,
                    style: TextStyle(
                      color: slateColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // Information Block
            _buildSectionHeader("PERSONAL INFORMATION", primaryColor),
            _buildInfoCard([
              _buildInfoRow(
                CupertinoIcons.mail_solid,
                "Email Address",
                email,
                textColor,
                slateColor,
              ),
              _buildDivider(primaryColor),
              _buildInfoRow(
                CupertinoIcons.phone_fill,
                "Phone Number",
                phone,
                textColor,
                slateColor,
              ),
            ], primaryColor),

            const SizedBox(height: 24),

            _buildSectionHeader("ACCOMMODATION DETAILS", primaryColor),
            _buildInfoCard([
              _buildInfoRow(
                CupertinoIcons.building_2_fill,
                "Property",
                accName,
                textColor,
                slateColor,
              ),
              _buildDivider(primaryColor),
              _buildInfoRow(
                CupertinoIcons.layers_fill,
                "Block",
                blockName,
                textColor,
                slateColor,
              ),
              _buildDivider(primaryColor),
              _buildInfoRow(
                CupertinoIcons.bed_double_fill,
                "Room Number",
                roomNum,
                textColor,
                slateColor,
              ),
            ], primaryColor),

            const SizedBox(height: 32),

            // Emergency & Medical Section
            _buildSectionHeader("EMERGENCY & MEDICAL", Colors.redAccent),
            _buildInfoCard([
              _buildActionRow(
                CupertinoIcons.heart_fill,
                "Medical Profile",
                "Update health & contact info",
                textColor,
                slateColor,
                () {
                  Navigator.push(
                    context,
                    CupertinoPageRoute(
                      builder: (_) => const MedicalDataEntryScreen(),
                    ),
                  );
                },
                iconColor: Colors.redAccent,
              ),
            ], Colors.redAccent),

            const SizedBox(height: 32),

            // Settings & Legal
            _buildSectionHeader("SETTINGS & LEGAL", primaryColor),
            _buildInfoCard([
              _buildActionRow(
                CupertinoIcons.lock_shield_fill,
                "Reset Password",
                "Send reset link to email",
                textColor,
                slateColor,
                () {
                  _resetPassword(context, email);
                },
              ),
              _buildDivider(primaryColor),
              _buildActionRow(
                CupertinoIcons.doc_text_fill,
                "Terms & Conditions",
                "Read our rules & policies",
                textColor,
                slateColor,
                () async {
                  final Uri url = Uri.parse("https://mst.mktechcloud.co.za/terms-and-conditions");
                  if (!await launchUrl(url, mode: LaunchMode.inAppBrowserView)) {
                    debugPrint("Could not launch Terms & Conditions.");
                  }
                },
              ),
              _buildDivider(primaryColor),
              _buildActionRow(
                CupertinoIcons.shield_fill,
                "Privacy Policy",
                "How we handle your data",
                textColor,
                slateColor,
                () async {
                  final Uri url = Uri.parse("https://mst.mktechcloud.co.za/privacy-policy");
                  if (!await launchUrl(url, mode: LaunchMode.inAppBrowserView)) {
                    debugPrint("Could not launch Privacy Policy.");
                  }
                },
              ),
              _buildDivider(primaryColor),
              _buildActionRow(
                CupertinoIcons.person_crop_circle_badge_xmark,
                "Delete Account",
                "Irreversibly wipe your profile data",
                textColor,
                slateColor,
                () {
                  _deleteAccountWorkflow();
                },
                iconColor: Colors.redAccent,
              ),
            ], primaryColor),

            const SizedBox(height: 32),

            // Logout Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  FaceCacheService().clearCache();
                  widget.onLogout();
                },
                icon: const Icon(CupertinoIcons.square_arrow_right),
                label: const Text(
                  'SIGN OUT SECURELY',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.withOpacity(0.1),
                  foregroundColor: Colors.redAccent,
                  elevation: 0,
                  side: BorderSide(color: Colors.red.withOpacity(0.3)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: color,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> children, Color primary) {
    return Container(
      decoration: BoxDecoration(
        color: primary.withOpacity(0.02),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: primary.withOpacity(0.1)),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value,
    Color textColor,
    Color slateColor,
  ) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Icon(icon, color: slateColor.withOpacity(0.5), size: 22),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: slateColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow(
    IconData icon,
    String title,
    String subtitle,
    Color textColor,
    Color slateColor,
    VoidCallback onTap, {
    Color? iconColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (iconColor ?? textColor).withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor ?? textColor, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: slateColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              CupertinoIcons.chevron_right,
              color: slateColor.withOpacity(0.5),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(Color primary) {
    return Divider(
      height: 1,
      thickness: 1,
      color: primary.withOpacity(0.05),
      indent: 56,
    );
  }
}