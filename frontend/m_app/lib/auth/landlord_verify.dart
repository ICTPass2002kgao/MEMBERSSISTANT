import 'dart:io' show Platform;
import 'dart:typed_data';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'face_verify.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:signature/signature.dart';

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

class _LandlordVerificationScreenState
    extends State<LandlordVerificationScreen> {
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

    // UPDATED FOR FILE_PICKER V12: Using pickFile() and readAsBytes()
    PlatformFile? file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );

    if (file != null) {
      // V12 explicitly requires calling readAsBytes()
      Uint8List bytes = await file.readAsBytes();
      setState(() {
        _idDocumentBytes = bytes;
        _idDocumentName = file.name;
      });
    }
  }

  // Generate the Final Legal PDF (With Signature)
  Future<Uint8List> _generateLegalContractPdf(
    Uint8List signatureBytes,
    String fullName,
    String email,
    String idNumber,
  ) async {
    final pdf = pw.Document();
    final String currentDate = DateFormat(
      'yyyy-MM-dd HH:mm:ss',
    ).format(DateTime.now());
    final signatureImage = pw.MemoryImage(signatureBytes);

    // MultiPage allows the long 20-point contract to cleanly flow across multiple pages
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            ..._buildSharedPdfContent(fullName, email, idNumber),
            pw.SizedBox(height: 30),
            pw.Divider(),
            pw.SizedBox(height: 10),
            pw.Text(
              "FINAL DIGITAL AUTHORIZATION",
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            pw.Text(
              "By my signature below, I acknowledge that this electronic signature carries the exact same legal weight and enforceability as a physical handwritten signature.",
            ),
            pw.SizedBox(height: 20),
            pw.Container(
              height: 100,
              width: 250,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey),
              ),
              child: pw.Image(signatureImage, fit: pw.BoxFit.contain),
            ),
            pw.SizedBox(height: 10),
            pw.Text("Digitally signed by: $fullName"),
            pw.Text("Timestamp: $currentDate"),
            pw.Text("Device Fingerprint: $_deviceId"),
          ];
        },
      ),
    );

    return await pdf.save();
  }

  // Generate a Draft copy of the PDF (without signature) for downloading to read
  Future<Uint8List> _generateDraftContractPdf(
    String fullName,
    String email,
    String idNumber,
  ) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            ..._buildSharedPdfContent(fullName, email, idNumber),
            pw.SizedBox(height: 30),
            pw.Divider(),
            pw.SizedBox(height: 10),
            pw.Text(
              "NOTE: This is a draft copy provided for your records and reading purposes. To operate as a verified landlord, you must digitally sign the final version inside the application.",
              style: pw.TextStyle(
                fontSize: 10,
                fontStyle: pw.FontStyle.italic,
                color: PdfColors.grey700,
              ),
            ),
          ];
        },
      ),
    );

    return await pdf.save();
  }

  Future<void> _downloadReadingCopy() async {
    setState(() => _isGeneratingPdf = true);
    try {
      final String fullName =
          "${widget.userData['name'] ?? ''} ${widget.userData['surname'] ?? ''}"
              .trim();
      final String email = widget.userData['email'] ?? 'No Email';
      final String idNumber = widget.userData['id_number'] ?? '';

      final Uint8List pdfBytes = Uint8List.fromList(
        await _generateDraftContractPdf(fullName, email, idNumber),
      );

      // UPDATED FOR FILE_PICKER V12: saveFile returns a Uri? and takes bytes directly.
      Uri? outputFile = await FilePicker.saveFile(
        dialogTitle: 'Save Contract Draft',
        fileName: 'Landlord_Agreement_Draft.pdf',
        bytes: pdfBytes,
      );

      if (outputFile != null) {
        _showMessage("Contract saved successfully.", Colors.green);
      }
    } catch (e) {
      _showMessage("Error saving document: $e", Colors.red);
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  Future<void> _proceedToLiveCapture() async {
    if (!_agreedToPopiaAndContract) {
      _showMessage(
        "Please agree to the POPIA & Contract terms before proceeding.",
        Colors.red,
      );
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
      final Uint8List? rawSignatureBytes = await _signatureController
          .toPngBytes();
      if (rawSignatureBytes == null)
        throw Exception("Failed to process signature.");

      final String fullName =
          "${widget.userData['name'] ?? ''} ${widget.userData['surname'] ?? ''}"
              .trim();
      final String email = widget.userData['email'] ?? 'No Email';
      final String idNumber = widget.userData['id_number'] ?? '';

      final Uint8List contractPdfBytes = Uint8List.fromList(
        await _generateLegalContractPdf(
          rawSignatureBytes,
          fullName,
          email,
          idNumber,
        ),
      );

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

  pw.Widget _pdfClause(String title, String body) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 12),
      child: pw.RichText(
        text: pw.TextSpan(
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.black),
          children: [
            pw.TextSpan(
              text: "$title ",
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.TextSpan(text: body),
          ],
        ),
      ),
    );
  }

  List<pw.Widget> _buildSharedPdfContent(
    String fullName,
    String email,
    String idNumber,
  ) {
    return [
      pw.Center(
        child: pw.Text(
          "LANDLORD PLATFORM AGREEMENT",
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue900,
          ),
        ),
      ),
      pw.SizedBox(height: 4),
      pw.Center(
        child: pw.Text(
          "TERMS OF SERVICE • VERIFICATION • TRIAL • PLATFORM USE",
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey700,
          ),
        ),
      ),
      pw.SizedBox(height: 16),
      pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: PdfColors.blue50,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
          border: pw.Border.all(color: PdfColors.blue200),
        ),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Text(
                "IMPORTANT: Your 30-day free trial begins immediately after you electronically sign and accept this Agreement. You may terminate your participation at any time during the free trial without being required to continue into the paid service period.",
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.black,
                ),
              ),
            ),
          ],
        ),
      ),
      pw.SizedBox(height: 16),
      pw.Text(
        "PARTIES TO THE AGREEMENT",
        style: pw.TextStyle(
          fontWeight: pw.FontWeight.bold,
          fontSize: 12,
          color: PdfColors.blue900,
        ),
      ),
      pw.SizedBox(height: 6),
      pw.Text(
        "This Landlord Platform Agreement (\"Agreement\") is entered into electronically between the platform operator (\"Platform\") and $fullName (\"Landlord\"). By reviewing, accepting and electronically signing this Agreement, the Landlord confirms that they have read, understood and agreed to the terms contained herein.",
        style: const pw.TextStyle(fontSize: 10),
      ),
      pw.SizedBox(height: 14),

      // All 20 Points verbatim
      _pdfClause(
        "1. LANDLORD REPRESENTATION AND AUTHORITY",
        "The Landlord represents and warrants that they are the lawful owner, authorised property manager, agent, representative or otherwise legally authorised person responsible for the accommodation and properties submitted to the Platform. The Landlord must provide accurate and truthful information regarding their identity, properties, availability, pricing, facilities and applicable accommodation conditions.",
      ),
      _pdfClause(
        "2. PROPERTY VERIFICATION",
        "The Platform may request supporting documentation or information reasonably necessary to verify the identity, authority and legitimacy of the Landlord and/or listed accommodation. The Landlord agrees that information submitted during verification must be complete, accurate and not misleading.",
      ),
      _pdfClause(
        "3. 30-DAY FREE TRIAL PERIOD",
        "The Landlord receives a thirty (30) day free trial of the Platform's applicable landlord services. The free trial begins immediately after the Landlord electronically signs and accepts this Agreement. No ambiguity exists regarding the commencement of the trial: the signing and acceptance of this Agreement constitutes the commencement event for the free trial.",
      ),
      _pdfClause(
        "4. RIGHT TO TERMINATE DURING THE FREE TRIAL",
        "The Landlord retains the right to terminate this Agreement during the thirty (30) day free trial period. The Landlord may exercise this right before the trial expires without being required to continue with the paid service period. Termination does not remove or affect obligations that arose before the effective date of termination, including obligations relating to fraud, unlawful conduct, misuse of the Platform or inaccurate information.",
      ),
      _pdfClause(
        "5. TRANSITION AFTER THE FREE TRIAL",
        "Unless the Landlord terminates the Agreement before the expiry of the free trial period, continued use of applicable paid Platform services after the trial may be subject to the Platform's then-current subscription, service or maintenance fees. Any applicable pricing, billing arrangements and payment terms should be communicated to the Landlord before or during the applicable service period.",
      ),
      _pdfClause(
        "6. ACCURACY OF PROPERTY LISTINGS",
        "The Landlord is responsible for ensuring that all property listings remain accurate and up to date. This includes, but is not limited to, property location, room availability, pricing, capacity, amenities, photographs, rules, contact information and accommodation status. The Landlord must promptly correct information that becomes inaccurate or misleading.",
      ),
      _pdfClause(
        "7. FRAUD, MISREPRESENTATION AND SCAMS",
        "The Landlord must not use the Platform to advertise non-existent accommodation, impersonate another person or organisation, submit fraudulent documentation, misrepresent ownership or authority, solicit payments through deceptive means, or engage in any fraudulent, unlawful or abusive activity. Where credible evidence of fraud or unlawful activity exists, the Platform may restrict, suspend or terminate the account and may take further action permitted by applicable law.",
      ),
      _pdfClause(
        "8. FINANCIAL AND STUDENT TRANSACTIONS",
        "The Landlord remains responsible for the accuracy of any financial information, rental amounts, deposits, fees or other charges communicated to prospective or existing residents. The Landlord must not knowingly request payments for services or accommodation that are unavailable, unauthorised or falsely represented.",
      ),
      _pdfClause(
        "9. PLATFORM SUSPENSION AND ACCOUNT RESTRICTIONS",
        "The Platform may temporarily restrict, suspend or permanently terminate access where there is a reasonable basis to believe that the Landlord has violated this Agreement, submitted false information, compromised Platform security, abused users, engaged in fraudulent activity or otherwise created a material risk to students, residents, landlords or the Platform.",
      ),
      _pdfClause(
        "10. IDENTITY, VERIFICATION AND DIGITAL RECORDS",
        "The Landlord acknowledges that identity and verification information may be collected and processed for legitimate verification, security, fraud-prevention, account-management and compliance purposes, subject to applicable data-protection and privacy laws and the Platform's applicable privacy policy.",
      ),
      _pdfClause(
        "11. FRAUD INVESTIGATION AND LEGAL COOPERATION",
        "Where permitted or required by applicable law, the Platform may preserve relevant account, transaction, verification and contractual records and cooperate with competent authorities in relation to suspected fraud, unlawful activity, threats, abuse or other serious violations. Information will not be disclosed merely because a dispute exists; disclosures will be handled in accordance with applicable legal requirements.",
      ),
      _pdfClause(
        "12. LANDLORD RESPONSIBILITIES",
        "The Landlord remains responsible for complying with all laws, regulations, municipal requirements, accommodation standards, lease obligations and other legal requirements applicable to their properties and business activities. Platform listing or verification does not constitute a guarantee that a property complies with every legal or regulatory requirement.",
      ),
      _pdfClause(
        "13. PLATFORM ROLE",
        "The Platform provides technology and digital services intended to facilitate property management, discovery, communication, verification and related accommodation processes. Unless expressly stated otherwise, the Platform does not become the owner, landlord, property manager, lessor or agent of any property merely because the property is listed on the Platform.",
      ),
      _pdfClause(
        "14. USER CONDUCT",
        "The Landlord agrees to communicate professionally and respectfully with students, residents, administrators and other Platform users. Harassment, intimidation, discrimination, threats, abusive communication, deliberate misinformation and misuse of the Platform are prohibited.",
      ),
      _pdfClause(
        "15. CONFIDENTIALITY AND RESPONSIBLE INFORMATION USE",
        "The Landlord must use information obtained through the Platform only for legitimate accommodation and property-management purposes and must take reasonable steps to prevent unauthorised access, disclosure or misuse of information relating to students, residents and other users.",
      ),
      _pdfClause(
        "16. ELECTRONIC SIGNATURE AND ACCEPTANCE",
        "The Landlord acknowledges that electronic acceptance and/or electronic signature of this Agreement constitutes their confirmation that they have reviewed the Agreement and agree to be bound by its applicable terms, subject to applicable law.",
      ),
      _pdfClause(
        "17. TERMINATION AFTER THE TRIAL PERIOD",
        "After the free trial period, termination will be governed by the applicable subscription, service or commercial terms then in effect. Where the Platform provides a specific cancellation process or notice requirement, the Landlord must follow that process to ensure that termination is properly recorded.",
      ),
      _pdfClause(
        "18. CHANGES TO PLATFORM SERVICES",
        "The Platform may improve, modify, update or discontinue features from time to time. Where a material change affects the Landlord's contractual or financial obligations, the Platform should provide appropriate notice where required by applicable law or the applicable service terms.",
      ),
      _pdfClause(
        "19. GOVERNING LAW",
        "This Agreement shall be interpreted and applied in accordance with applicable law. Nothing in this Agreement is intended to exclude or limit any right or protection that cannot lawfully be excluded or limited.",
      ),
      _pdfClause(
        "20. ACKNOWLEDGEMENT",
        "By signing this Agreement, I, $fullName, confirm that I have read and understood these terms, that the information I have provided is truthful and accurate to the best of my knowledge, and that I understand that my thirty (30) day free trial begins immediately after electronic signing and acceptance. I further confirm that I retain the right to terminate the Agreement during the free trial period before the trial expires.",
      ),

      pw.SizedBox(height: 14),

      // Electronic Acceptance Box
      pw.Container(
        padding: const pw.EdgeInsets.all(14),
        decoration: pw.BoxDecoration(
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
          color: PdfColors.grey100,
          border: pw.Border.all(color: PdfColors.grey300),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              "ELECTRONIC ACCEPTANCE",
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue900,
              ),
            ),
            pw.SizedBox(height: 7),
            pw.Text(
              "Landlord: $fullName\n"
              "Agreement Status: Pending Electronic Signature\n"
              "Trial Period: 30 Days From Electronic Acceptance\n"
              "Termination During Trial: Permitted\n"
              "Contract Type: Landlord Platform Agreement",
              style: const pw.TextStyle(fontSize: 9, lineSpacing: 1.5),
            ),
          ],
        ),
      ),

      pw.SizedBox(height: 12),

      pw.Text(
        "IMPORTANT LEGAL NOTICE",
        style: pw.TextStyle(
          fontWeight: pw.FontWeight.bold,
          fontSize: 10,
          color: PdfColors.red800,
        ),
      ),
      pw.SizedBox(height: 5),
      pw.Text(
        "This Agreement is intended to establish the terms governing access to and use of the Platform by verified landlords. It should be reviewed against the Platform's privacy policy, subscription terms and applicable South African law before being used as a final legal contract.",
        style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
      ),
    ];
  }

  Widget _buildContractPreview(String fullName, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 420,
          padding: const EdgeInsets.all(18),
          decoration: _innerGlassDecoration(theme),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Text(
                    "LANDLORD PLATFORM AGREEMENT",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),

                const SizedBox(height: 4),

                Center(
                  child: Text(
                    "TERMS OF SERVICE • VERIFICATION • TRIAL • PLATFORM USE",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                      color: theme.colorScheme.onSurface.withOpacity(0.65),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: theme.colorScheme.primary.withOpacity(0.25),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "IMPORTANT: Your 30-day free trial begins immediately "
                          "after you electronically sign and accept this Agreement. "
                          "You may terminate your participation at any time during "
                          "the free trial without being required to continue into "
                          "the paid service period.",
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.45,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                Text(
                  "PARTIES TO THE AGREEMENT",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: theme.colorScheme.primary,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  "This Landlord Platform Agreement (\"Agreement\") is entered into "
                  "electronically between the platform operator (\"Platform\") and "
                  "$fullName (\"Landlord\"). By reviewing, accepting and electronically "
                  "signing this Agreement, the Landlord confirms that they have read, "
                  "understood and agreed to the terms contained herein.",
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.5,
                    color: theme.colorScheme.onSurface,
                  ),
                ),

                const SizedBox(height: 14),

                _contractClause(
                  "1. LANDLORD REPRESENTATION AND AUTHORITY",
                  "The Landlord represents and warrants that they are the lawful "
                      "owner, authorised property manager, agent, representative or "
                      "otherwise legally authorised person responsible for the "
                      "accommodation and properties submitted to the Platform. The "
                      "Landlord must provide accurate and truthful information regarding "
                      "their identity, properties, availability, pricing, facilities "
                      "and applicable accommodation conditions.",
                  theme,
                ),

                _contractClause(
                  "2. PROPERTY VERIFICATION",
                  "The Platform may request supporting documentation or information "
                      "reasonably necessary to verify the identity, authority and "
                      "legitimacy of the Landlord and/or listed accommodation. The "
                      "Landlord agrees that information submitted during verification "
                      "must be complete, accurate and not misleading.",
                  theme,
                ),

                _contractClause(
                  "3. 30-DAY FREE TRIAL PERIOD",
                  "The Landlord receives a thirty (30) day free trial of the "
                      "Platform's applicable landlord services. The free trial begins "
                      "immediately after the Landlord electronically signs and accepts "
                      "this Agreement. No ambiguity exists regarding the commencement "
                      "of the trial: the signing and acceptance of this Agreement "
                      "constitutes the commencement event for the free trial.",
                  theme,
                ),

                _contractClause(
                  "4. RIGHT TO TERMINATE DURING THE FREE TRIAL",
                  "The Landlord retains the right to terminate this Agreement "
                      "during the thirty (30) day free trial period. The Landlord may "
                      "exercise this right before the trial expires without being "
                      "required to continue with the paid service period. Termination "
                      "does not remove or affect obligations that arose before the "
                      "effective date of termination, including obligations relating "
                      "to fraud, unlawful conduct, misuse of the Platform or inaccurate "
                      "information.",
                  theme,
                ),

                _contractClause(
                  "5. TRANSITION AFTER THE FREE TRIAL",
                  "Unless the Landlord terminates the Agreement before the expiry "
                      "of the free trial period, continued use of applicable paid "
                      "Platform services after the trial may be subject to the "
                      "Platform's then-current subscription, service or maintenance "
                      "fees. Any applicable pricing, billing arrangements and payment "
                      "terms should be communicated to the Landlord before or during "
                      "the applicable service period.",
                  theme,
                ),

                _contractClause(
                  "6. ACCURACY OF PROPERTY LISTINGS",
                  "The Landlord is responsible for ensuring that all property "
                      "listings remain accurate and up to date. This includes, but is "
                      "not limited to, property location, room availability, pricing, "
                      "capacity, amenities, photographs, rules, contact information "
                      "and accommodation status. The Landlord must promptly correct "
                      "information that becomes inaccurate or misleading.",
                  theme,
                ),

                _contractClause(
                  "7. FRAUD, MISREPRESENTATION AND SCAMS",
                  "The Landlord must not use the Platform to advertise non-existent "
                      "accommodation, impersonate another person or organisation, "
                      "submit fraudulent documentation, misrepresent ownership or "
                      "authority, solicit payments through deceptive means, or engage "
                      "in any fraudulent, unlawful or abusive activity. Where credible "
                      "evidence of fraud or unlawful activity exists, the Platform may "
                      "restrict, suspend or terminate the account and may take further "
                      "action permitted by applicable law.",
                  theme,
                ),

                _contractClause(
                  "8. FINANCIAL AND STUDENT TRANSACTIONS",
                  "The Landlord remains responsible for the accuracy of any "
                      "financial information, rental amounts, deposits, fees or other "
                      "charges communicated to prospective or existing residents. "
                      "The Landlord must not knowingly request payments for services "
                      "or accommodation that are unavailable, unauthorised or falsely "
                      "represented.",
                  theme,
                ),

                _contractClause(
                  "9. PLATFORM SUSPENSION AND ACCOUNT RESTRICTIONS",
                  "The Platform may temporarily restrict, suspend or permanently "
                      "terminate access where there is a reasonable basis to believe "
                      "that the Landlord has violated this Agreement, submitted false "
                      "information, compromised Platform security, abused users, "
                      "engaged in fraudulent activity or otherwise created a material "
                      "risk to students, residents, landlords or the Platform.",
                  theme,
                ),

                _contractClause(
                  "10. IDENTITY, VERIFICATION AND DIGITAL RECORDS",
                  "The Landlord acknowledges that identity and verification "
                      "information may be collected and processed for legitimate "
                      "verification, security, fraud-prevention, account-management "
                      "and compliance purposes, subject to applicable data-protection "
                      "and privacy laws and the Platform's applicable privacy policy.",
                  theme,
                ),

                _contractClause(
                  "11. FRAUD INVESTIGATION AND LEGAL COOPERATION",
                  "Where permitted or required by applicable law, the Platform "
                      "may preserve relevant account, transaction, verification and "
                      "contractual records and cooperate with competent authorities "
                      "in relation to suspected fraud, unlawful activity, threats, "
                      "abuse or other serious violations. Information will not be "
                      "disclosed merely because a dispute exists; disclosures will "
                      "be handled in accordance with applicable legal requirements.",
                  theme,
                ),

                _contractClause(
                  "12. LANDLORD RESPONSIBILITIES",
                  "The Landlord remains responsible for complying with all laws, "
                      "regulations, municipal requirements, accommodation standards, "
                      "lease obligations and other legal requirements applicable to "
                      "their properties and business activities. Platform listing or "
                      "verification does not constitute a guarantee that a property "
                      "complies with every legal or regulatory requirement.",
                  theme,
                ),

                _contractClause(
                  "13. PLATFORM ROLE",
                  "The Platform provides technology and digital services intended "
                      "to facilitate property management, discovery, communication, "
                      "verification and related accommodation processes. Unless "
                      "expressly stated otherwise, the Platform does not become the "
                      "owner, landlord, property manager, lessor or agent of any "
                      "property merely because the property is listed on the Platform.",
                  theme,
                ),

                _contractClause(
                  "14. USER CONDUCT",
                  "The Landlord agrees to communicate professionally and "
                      "respectfully with students, residents, administrators and "
                      "other Platform users. Harassment, intimidation, discrimination, "
                      "threats, abusive communication, deliberate misinformation and "
                      "misuse of the Platform are prohibited.",
                  theme,
                ),

                _contractClause(
                  "15. CONFIDENTIALITY AND RESPONSIBLE INFORMATION USE",
                  "The Landlord must use information obtained through the Platform "
                      "only for legitimate accommodation and property-management "
                      "purposes and must take reasonable steps to prevent unauthorised "
                      "access, disclosure or misuse of information relating to "
                      "students, residents and other users.",
                  theme,
                ),

                _contractClause(
                  "16. ELECTRONIC SIGNATURE AND ACCEPTANCE",
                  "The Landlord acknowledges that electronic acceptance and/or "
                      "electronic signature of this Agreement constitutes their "
                      "confirmation that they have reviewed the Agreement and agree "
                      "to be bound by its applicable terms, subject to applicable law.",
                  theme,
                ),

                _contractClause(
                  "17. TERMINATION AFTER THE TRIAL PERIOD",
                  "After the free trial period, termination will be governed by "
                      "the applicable subscription, service or commercial terms then "
                      "in effect. Where the Platform provides a specific cancellation "
                      "process or notice requirement, the Landlord must follow that "
                      "process to ensure that termination is properly recorded.",
                  theme,
                ),

                _contractClause(
                  "18. CHANGES TO PLATFORM SERVICES",
                  "The Platform may improve, modify, update or discontinue "
                      "features from time to time. Where a material change affects "
                      "the Landlord's contractual or financial obligations, the "
                      "Platform should provide appropriate notice where required by "
                      "applicable law or the applicable service terms.",
                  theme,
                ),

                _contractClause(
                  "19. GOVERNING LAW",
                  "This Agreement shall be interpreted and applied in accordance "
                      "with applicable law. Nothing in this Agreement is intended to "
                      "exclude or limit any right or protection that cannot lawfully "
                      "be excluded or limited.",
                  theme,
                ),

                _contractClause(
                  "20. ACKNOWLEDGEMENT",
                  "By signing this Agreement, I, $fullName, confirm that I have "
                      "read and understood these terms, that the information I have "
                      "provided is truthful and accurate to the best of my knowledge, "
                      "and that I understand that my thirty (30) day free trial begins "
                      "immediately after electronic signing and acceptance. I further "
                      "confirm that I retain the right to terminate the Agreement "
                      "during the free trial period before the trial expires.",
                  theme,
                ),

                const SizedBox(height: 14),

                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: theme.colorScheme.primary.withOpacity(0.06),
                    border: Border.all(
                      color: theme.colorScheme.primary.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "ELECTRONIC ACCEPTANCE",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        "Landlord: $fullName\n"
                        "Agreement Status: Pending Electronic Signature\n"
                        "Trial Period: 30 Days From Electronic Acceptance\n"
                        "Termination During Trial: Permitted\n"
                        "Contract Type: Landlord Platform Agreement",
                        style: TextStyle(
                          fontSize: 10.5,
                          height: 1.5,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  "IMPORTANT LEGAL NOTICE",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: theme.colorScheme.error,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  "This Agreement is intended to establish the terms governing "
                  "access to and use of the Platform by verified landlords. "
                  "It should be reviewed against the Platform's privacy policy, "
                  "subscription terms and applicable South African law before "
                  "being used as a final legal contract.",
                  style: TextStyle(
                    fontSize: 9.5,
                    height: 1.45,
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Download Reading Copy Button
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _isGeneratingPdf ? null : _downloadReadingCopy,
            icon: _isGeneratingPdf
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    Icons.download_rounded,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
            label: Text(
              "Download Reading Copy",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            style: TextButton.styleFrom(
              backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
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
        "${widget.userData['name'] ?? ''} ${widget.userData['surname'] ?? ''}"
            .trim();

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
                                onPressed: () {
                                  Navigator.pushNamedAndRemoveUntil(
                                    context,
                                    '/login',
                                    (route) => false,
                                  );
                                },
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
                                  backgroundColor: theme.scaffoldBackgroundColor
                                      .withOpacity(0.9),
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
                            onPressed: _isGeneratingPdf
                                ? null
                                : _proceedToLiveCapture,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _agreedToPopiaAndContract
                                  ? primaryColor
                                  : theme.colorScheme.onSecondary.withOpacity(
                                      0.5,
                                    ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 8,
                              shadowColor: primaryColor.withOpacity(0.5),
                            ),
                            child: _isGeneratingPdf
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
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
