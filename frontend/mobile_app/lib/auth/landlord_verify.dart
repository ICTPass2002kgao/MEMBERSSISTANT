import 'dart:io' show Platform;
import 'dart:typed_data';
import 'dart:ui';
 
import 'package:file_picker/file_picker.dart'; 
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart'; 
import 'package:intl/intl.dart';
import 'package:mobile_app/auth/face_verify.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw; 
import 'package:signature/signature.dart';
 

import '../components/liveness_wrapper.dart'
    if (dart.library.io) '../components/liveness_wrapper_mobile.dart'
    if (dart.library.html) '../components/liveness_wrapper_web.dart';

// ----------------------------------------------------------------------
// REUSABLE BACKGROUND
// ----------------------------------------------------------------------
class BubbleBackground extends StatelessWidget {
  const BubbleBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Stack(
      children: [
        Positioned(
          top: -80,
          left: -50,
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [primary.withOpacity(0.8), primary.withOpacity(0.4)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: primary.withOpacity(0.3),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: -100,
          right: -80,
          child: Container(
            width: 320,
            height: 320,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  Colors.teal.withOpacity(0.6),
                  primary.withOpacity(0.6),
                ],
                begin: Alignment.bottomRight,
                end: Alignment.topLeft,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.teal.withOpacity(0.2),
                  blurRadius: 40,
                  spreadRadius: 5,
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 250,
          right: -60,
          child: Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  Colors.orangeAccent.withOpacity(0.7),
                  Colors.deepOrange.withOpacity(0.5),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withOpacity(0.2),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ----------------------------------------------------------------------
// SCREEN 1: CONTRACT & ID UPLOAD
// ----------------------------------------------------------------------
class LandlordVerificationScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const LandlordVerificationScreen({super.key, required this.userData});

  @override
  State<LandlordVerificationScreen> createState() =>
      _LandlordVerificationScreenState();
}

class _LandlordVerificationScreenState extends State<LandlordVerificationScreen> {
  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  Uint8List? _idDocumentBytes;
  String? _idDocumentName;

  bool _agreedToPopiaAndContract = false;
  bool _isGeneratingPdf = false;

  String get _deviceId {
    try {
      return "${Platform.operatingSystem}_${DateTime.now().millisecondsSinceEpoch}";
    } catch (e) {
      return "Unknown_Device_${DateTime.now().millisecondsSinceEpoch}";
    }
  }

  void _showMessage(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _pickIdDocument() async {
    if (!_agreedToPopiaAndContract) {
      _showMessage(
        "You must agree to the POPIA Data consent and Contract Terms first.",
        Colors.orange,
      );
      return;
    }
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (result != null && result.files.single.bytes != null) {
      setState(() {
        _idDocumentBytes = result.files.single.bytes;
        _idDocumentName = result.files.single.name;
      });
    }
  }

  Future<Uint8List> _generateLegalContractPdf(
      Uint8List signatureBytes, String fullName, String email, String idNumber) async {
    final pdf = pw.Document();
    final String currentDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    final signatureImage = pw.MemoryImage(signatureBytes);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text("STRICT FRAUD LIABILITY & SERVICE AGREEMENT",
                    style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.red800)),
              ),
              pw.SizedBox(height: 20),
              pw.Divider(thickness: 2),
              pw.SizedBox(height: 20),
              pw.Text("PARTIES TO THE AGREEMENT:",
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Text("This binding agreement is executed by and between the Platform Administration and:"),
              pw.Text("Full Name: $fullName"),
              pw.Text("Email Address: $email"),
              pw.Text("National ID / Passport: ${idNumber.isNotEmpty ? idNumber : 'Verified via App'}"),
              pw.SizedBox(height: 20),
              pw.Text("TERMS AND CONDITIONS:",
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Paragraph(
                  text:
                      "1. GUARANTEE OF ACCOMMODATION: I declare under penalty of perjury that I legally manage or own the properties I am listing. I commit to fulfilling all residential obligations to students who apply through this platform."),
              pw.Paragraph(
                  text:
                      "2. FRAUD AND SCAM ACCOUNTABILITY: I understand that listing phantom properties, requesting deposits for non-existent rooms, or engaging in any form of financial scam is a direct violation of the law. I accept full legal and financial liability for any damages caused by fraudulent listings associated with my account."),
              pw.Paragraph(
                  text:
                      "3. LAW ENFORCEMENT COOPERATION: In the event of suspected fraud, the platform reserves the unconditional right to immediately suspend my account and hand over this digitally signed contract, my uploaded Identity Document, my Facial Biometric scans, and my device IP logs to the South African Police Service (SAPS) or relevant law enforcement agencies."),
              pw.Paragraph(
                  text:
                      "4. POPIA DATA CONSENT: I explicitly consent to the encrypted server storage of my personal identification and biometric data. I acknowledge this data is collected strictly for identity verification and fraud prevention purposes."),
              pw.SizedBox(height: 30),
              pw.Divider(),
              pw.SizedBox(height: 10),
              pw.Text("DIGITAL AUTHORIZATION",
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Text(
                  "By my signature below, I acknowledge that this electronic signature carries the exact same legal weight and enforceability as a physical handwritten signature."),
              pw.SizedBox(height: 20),
              pw.Container(
                height: 100,
                width: 250,
                decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey)),
                child: pw.Image(signatureImage, fit: pw.BoxFit.contain),
              ),
              pw.SizedBox(height: 10),
              pw.Text("Digitally signed by: $fullName"),
              pw.Text("Timestamp: $currentDate"),
              pw.Text("Device Fingerprint: $_deviceId"),
            ],
          );
        },
      ),
    );

    return await pdf.save();
  }

  Future<void> _proceedToLiveCapture() async {
    if (!_agreedToPopiaAndContract) {
      _showMessage("Please agree to the POPIA & Contract terms before proceeding.", Colors.red);
      return;
    }
    if (_signatureController.isEmpty) {
      _showMessage("Please sign the digital contract.", Colors.red);
      return;
    }
    if (_idDocumentBytes == null) {
      _showMessage("Please upload your ID document.", Colors.red);
      return;
    }

    setState(() => _isGeneratingPdf = true);

    try {
      final Uint8List? rawSignatureBytes = await _signatureController.toPngBytes();
      if (rawSignatureBytes == null) throw Exception("Failed to process signature.");

      final String fullName =
          "${widget.userData['name'] ?? ''} ${widget.userData['surname'] ?? ''}".trim();
      final String email = widget.userData['email'] ?? 'No Email';
      final String idNumber = widget.userData['id_number'] ?? '';

      final Uint8List contractPdfBytes = await _generateLegalContractPdf(
          rawSignatureBytes, fullName, email, idNumber);

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LandlordFaceVerificationScreen(
            userData: widget.userData,
            contractPdfBytes: contractPdfBytes,
            idDocumentBytes: _idDocumentBytes!,
            idDocumentName: _idDocumentName ?? 'id_doc.pdf',
            deviceId: _deviceId,
          ),
        ),
      ).then((_) {
        setState(() {});
      });
    } catch (e) {
      _showMessage("Error generating secure contract: $e", Colors.red);
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  BoxDecoration _innerGlassDecoration(ThemeData theme) {
    return BoxDecoration(
      color: theme.colorScheme.primary.withOpacity(0.05),
      borderRadius: BorderRadius.circular(16),
    );
  }

  Widget _buildContractPreview(String fullName, ThemeData theme) {
    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: _innerGlassDecoration(theme),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "TERMS OF AGREEMENT AND STRICT FRAUD LIABILITY",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "I, $fullName, hereby acknowledge and legally bind myself to the following conditions of operating as a verified landlord on this platform:",
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            _contractClause(
              "1. GUARANTEE OF ACCOMMODATION:",
              "I declare under penalty of perjury that I legally manage or own the properties I am listing. I commit to fulfilling all residential obligations to students.",
              theme,
            ),
            _contractClause(
              "2. FRAUD AND SCAM ACCOUNTABILITY:",
              "I understand that listing phantom properties or engaging in any form of financial scam is a direct violation of the law. I accept full legal and financial liability.",
              theme,
            ),
            _contractClause(
              "3. PLATFORM RIGHTS & LAW ENFORCEMENT:",
              "The platform reserves the right to immediately suspend my account and hand over my provided ID Document, Biometric Face Image, and this digitally signed contract to law enforcement agencies in the event of fraud.",
              theme,
            ),
          ],
        ),
      ),
    );
  }

  Widget _contractClause(String title, String body, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: RichText(
        text: TextSpan(
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurface,
            height: 1.4,
          ),
          children: [
            TextSpan(
              text: "$title ",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: body),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final textColor = theme.colorScheme.onSurface;
    final String fullName =
        "${widget.userData['name'] ?? ''} ${widget.userData['surname'] ?? ''}".trim();

    if (widget.userData['manual_verification_status'] == true &&
        widget.userData['digital_verification_status'] == false) {
      return Scaffold(
        body: Stack(
          children: [
            const BubbleBackground(),
            SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        padding: const EdgeInsets.all(32.0),
                        decoration: BoxDecoration(
                          color: theme.scaffoldBackgroundColor.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(
                            color: primaryColor.withOpacity(0.4),
                            width: 0.7,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.pending_actions,
                              size: 80,
                              color: Colors.orange,
                            ),
                            const SizedBox(height: 20),
                            Text(
                              "Manual Review Pending",
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              "You have opted to submit your profile for manual verification. An administrator will review your provided ID document and contract shortly. Please wait for approval before accessing your dashboard.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: theme.colorScheme.onSecondary,
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 40),
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                onPressed: () => Navigator.pop(context),
                                child: const Text(
                                  "RETURN TO LOGIN",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Verification Setup',
          style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: Stack(
        children: [
          const BubbleBackground(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    padding: const EdgeInsets.all(24.0),
                    decoration: BoxDecoration(
                      color: theme.scaffoldBackgroundColor.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: primaryColor.withOpacity(0.4),
                        width: 0.7,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 40,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Step 1: Documentation",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: primaryColor,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "Provide your legal agreement and identification. This will be used in the next step to verify your live biometrics.",
                          style: TextStyle(
                            color: theme.colorScheme.onSecondary,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          "1. Review Legal Contract",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildContractPreview(fullName, theme),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: _innerGlassDecoration(theme),
                          child: Row(
                            children: [
                              Checkbox(
                                value: _agreedToPopiaAndContract,
                                activeColor: primaryColor,
                                onChanged: (val) {
                                  setState(() {
                                    _agreedToPopiaAndContract = val ?? false;
                                  });
                                },
                              ),
                              Expanded(
                                child: Text(
                                  "POPIA CONSENT: I explicitly consent to the encrypted server storage of my ID and Biometrics. Data is collected strictly for fraud-prevention.",
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: _agreedToPopiaAndContract
                                        ? primaryColor
                                        : Colors.red.shade400,
                                    fontWeight: _agreedToPopiaAndContract
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          "2. Digital Signature",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: _innerGlassDecoration(theme),
                          child: Column(
                            children: [
                              Text(
                                "By signing below, I, $fullName, agree that this electronic signature holds the exact same legal weight as a physical handwritten signature.",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Signature(
                                  controller: _signatureController,
                                  height: 150,
                                  backgroundColor:
                                      theme.scaffoldBackgroundColor.withOpacity(0.9),
                                ),
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () => _signatureController.clear(),
                                  child: const Text(
                                    "Clear Signature",
                                    style: TextStyle(color: Colors.redAccent),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          "3. Upload ID Document",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: _pickIdDocument,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              vertical: 32,
                              horizontal: 16,
                            ),
                            decoration: _innerGlassDecoration(theme),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.badge_outlined,
                                  size: 48,
                                  color: _idDocumentBytes != null
                                      ? primaryColor
                                      : theme.colorScheme.onSecondary,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _idDocumentBytes != null
                                      ? "ID Selected:\n$_idDocumentName"
                                      : "Tap to Upload ID\n(PDF, JPG, PNG)",
                                  style: TextStyle(
                                    color: _idDocumentBytes != null
                                        ? primaryColor
                                        : theme.colorScheme.onSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 48),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isGeneratingPdf ? null : _proceedToLiveCapture,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _agreedToPopiaAndContract
                                  ? primaryColor
                                  : theme.colorScheme.onSecondary.withOpacity(0.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 8,
                              shadowColor: primaryColor.withOpacity(0.5),
                            ),
                            child: _isGeneratingPdf
                                ? const CircularProgressIndicator(color: Colors.white)
                                : const Text(
                                    "PROCEED TO BIOMETRICS",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------
// SCREEN 2: LIVE CAMERA & BACKEND UPLOAD
// ----------------------------------------------------------------------
