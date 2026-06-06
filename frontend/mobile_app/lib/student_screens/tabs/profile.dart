import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StudentProfileScreen extends StatelessWidget {
  final Map<String, dynamic> userData;
  final VoidCallback onLogout;
  final String initials;

  const StudentProfileScreen({
    super.key,
    required this.userData,
    required this.onLogout,
    required this.initials,
  });

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final slateColor = theme.colorScheme.onSecondary;
    final textColor = theme.colorScheme.onSurface;

    // Strict Null Safety and Type Checking
    final String? faceUrl = userData['face_url']?.toString();
    final bool hasFace = faceUrl != null && faceUrl.trim().isNotEmpty;

    final String nameStr = "${userData['name']?.toString() ?? ''} ${userData['surname']?.toString() ?? ''}".trim();
    final String name = nameStr.isNotEmpty ? nameStr : 'Student';
    
    final String email = userData['email']?.toString() ?? 'No email provided';
    final String studentNo = userData['student_number']?.toString() ?? 'Unknown ID';
    final String phone = userData['phone']?.toString() ?? 'N/A';
    final String accName = userData['accommodation_name']?.toString() ?? 'Unassigned';
    final String blockName = userData['block_name']?.toString() ?? 'Unassigned';
    final String roomNum = userData['room_number_only']?.toString() ?? 'Unassigned';

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
                      border: Border.all(color: primaryColor.withOpacity(0.3), width: 2),
                    ),
                    child: CircleAvatar(
                      radius: 48,
                      backgroundColor: primaryColor.withOpacity(0.15),
                      backgroundImage: hasFace ? NetworkImage(faceUrl) : null,
                      child: !hasFace
                          ? Text(
                              initials.toUpperCase(),
                              style: TextStyle(color: primaryColor, fontWeight: FontWeight.w900, fontSize: 36),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(name, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: textColor)),
                  const SizedBox(height: 4),
                  Text(studentNo, style: TextStyle(color: slateColor, fontWeight: FontWeight.w700, fontSize: 14)),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // Information Block
            _buildSectionHeader("PERSONAL INFORMATION", primaryColor),
            _buildInfoCard([
              _buildInfoRow(CupertinoIcons.mail_solid, "Email Address", email, textColor, slateColor),
              _buildDivider(primaryColor),
              _buildInfoRow(CupertinoIcons.phone_fill, "Phone Number", phone, textColor, slateColor),
            ], primaryColor),

            const SizedBox(height: 24),

            _buildSectionHeader("ACCOMMODATION DETAILS", primaryColor),
            _buildInfoCard([
              _buildInfoRow(CupertinoIcons.building_2_fill, "Property", accName, textColor, slateColor),
              _buildDivider(primaryColor),
              _buildInfoRow(CupertinoIcons.layers_fill, "Block", blockName, textColor, slateColor),
              _buildDivider(primaryColor),
              _buildInfoRow(CupertinoIcons.bed_double_fill, "Room Number", roomNum, textColor, slateColor),
            ], primaryColor),

            const SizedBox(height: 32),

            // Settings & Legal
            _buildSectionHeader("SETTINGS & LEGAL", primaryColor),
            _buildInfoCard([
              _buildActionRow(CupertinoIcons.lock_shield_fill, "Reset Password", "Send reset link to email", textColor, slateColor, () {
                _resetPassword(context, email);
              }),
              _buildDivider(primaryColor),
              _buildActionRow(CupertinoIcons.doc_text_fill, "Terms & Conditions", "Read our rules & policies", textColor, slateColor, () {
                Navigator.push(context, CupertinoPageRoute(builder: (_) => const LegalDocumentScreen(isPrivacy: false)));
              }),
              _buildDivider(primaryColor),
              _buildActionRow(CupertinoIcons.shield_fill, "Privacy Policy", "How we handle your data", textColor, slateColor, () {
                Navigator.push(context, CupertinoPageRoute(builder: (_) => const LegalDocumentScreen(isPrivacy: true)));
              }),
            ], primaryColor),

            const SizedBox(height: 32),

            // Logout Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  onLogout();
                },
                icon: const Icon(CupertinoIcons.square_arrow_right),
                label: const Text(
                  'SIGN OUT SECURELY',
                  style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5),
                ),
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

  Widget _buildSectionHeader(String title, Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: primaryColor, letterSpacing: 1.5),
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

  Widget _buildInfoRow(IconData icon, String label, String value, Color textColor, Color slateColor) {
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
                Text(label, style: TextStyle(color: slateColor, fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow(IconData icon, String title, String subtitle, Color textColor, Color slateColor, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: textColor.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: textColor, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Text(title, style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w900)),
                 Text(subtitle, style: TextStyle(color: slateColor, fontSize: 11, fontWeight: FontWeight.bold)),
               ],
             ),
            ),
            Icon(CupertinoIcons.chevron_right, color: slateColor.withOpacity(0.5), size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(Color primary) {
    return Divider(height: 1, thickness: 1, color: primary.withOpacity(0.05), indent: 56);
  }
}

// ============================================================================
// LEGAL DOCUMENT SCREEN (T&C and Privacy Policy)
// ============================================================================
class LegalDocumentScreen extends StatelessWidget {
  final bool isPrivacy;
  
  const LegalDocumentScreen({super.key, required this.isPrivacy});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = isPrivacy ? "PRIVACY POLICY" : "TERMS & CONDITIONS";
    
    // Standard Boilerplate text so it works beautifully out of the box
    final content = isPrivacy ? _privacyText : _termsText;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(CupertinoIcons.back, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: theme.colorScheme.primary,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Text(
          content,
          style: TextStyle(
            color: theme.colorScheme.onSurface.withOpacity(0.8),
            fontSize: 14,
            height: 1.6,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  static const String _termsText = """
Last Updated: March 2026

1. ACCEPTANCE OF TERMS
By accessing and using this application, you accept and agree to be bound by the terms and provision of this agreement. In addition, when using these particular services, you shall be subject to any posted guidelines or rules applicable to such services.

2. RESIDENCE RULES
Students are expected to adhere to all physical accommodation rules set forth by their landlord. This application acts as a management layer, and misuse of the application (e.g., generating fraudulent gate passes) may result in immediate eviction.

3. MAINTENANCE REPORTING
Maintenance requests submitted through this app are queued based on priority. While management attempts to resolve all issues within 48 hours, this timeframe is not legally binding.

4. GATE PASSES & PERMITS
QR codes generated for gate passes and exit permits are strictly tied to your identity. Attempting to share your QR code with an unregistered individual is considered a severe security breach.

5. PAYMENTS
Any payments made via Paystack integration for lost keys or damages are final. Refunds must be requested directly from property management.

6. MODIFICATION
We reserve the right to modify these terms from time to time at our sole discretion. Therefore, you should review these pages periodically.
""";

  static const String _privacyText = """
Last Updated: March 2026

1. INFORMATION WE COLLECT
We collect personal information that you or your landlord provide to us. This includes your name, student number, ID number, email address, phone number, and a photograph of your face for biometric verification.

2. HOW WE USE YOUR INFORMATION
We use the information we collect or receive to:
• Facilitate account creation and logon process.
• Send administrative information to you.
• Verify your identity at security checkpoints using biometric facial recognition.
• Manage your residence, including maintenance and gate passes.

3. BIOMETRIC DATA
Your facial image is stored securely on Google Firebase and referenced by our Django backend solely for the purpose of matching your identity when you attempt to exit the premises. It is never sold to third parties.

4. DATA SECURITY
We have implemented appropriate technical and organizational security measures designed to protect the security of any personal information we process, including end-to-end encryption of sensitive details like ID numbers.

5. YOUR RIGHTS
You have the right to request access to the personal data we hold about you, and to ask that your personal data be corrected or updated.

By using this application, you consent to our Privacy Policy.
""";
}