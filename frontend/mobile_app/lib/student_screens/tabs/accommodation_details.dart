import 'dart:convert';
import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:mobile_app/components/api_class.dart';
import 'package:mobile_app/auth/login.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AccommodationDetailsScreen extends StatefulWidget {
  final Map<dynamic, dynamic> accommodation;

  const AccommodationDetailsScreen({super.key, required this.accommodation});

  @override
  State<AccommodationDetailsScreen> createState() =>
      _AccommodationDetailsScreenState();
}

class _AccommodationDetailsScreenState
    extends State<AccommodationDetailsScreen> {
  bool _isProcessing = false;

  Future<void> _handleApply() async {
    final user = FirebaseAuth.instance.currentUser;

    // 1. Check if authenticated (and not anonymous)
    if (user == null || user.isAnonymous) {
      _showLoginPrompt();
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final token = await user.getIdToken();

      // 2. Fetch current student profile to check documents
      // Replace with your actual endpoint to get the logged-in student's profile
      final profileResponse = await http.get(
        Uri.parse(
          '${ApiClass().getApiBaseUrl()}/students/me/',
        ), // Ensure this endpoint exists or adjust to your setup
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (profileResponse.statusCode == 200) {
        final profileData = jsonDecode(profileResponse.body);

        bool hasId = profileData['id_document_url'] != null;
        bool hasProof = profileData['proof_of_registration_url'] != null;

        // 3. Check if documents are uploaded
        if (!hasId || !hasProof) {
          setState(() => _isProcessing = false);
          _showDocumentUploadSheet(hasId, hasProof);
          return;
        }

        // 4. Proceed with application (simulate or call application API)
        await _submitApplication(token!);
      } else {
        throw Exception("Failed to retrieve profile data.");
      }
    } catch (e) {
      _showSnackBar("Application error: ${e.toString()}", Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _submitApplication(String token) async {
    // Replace with your actual endpoint to submit an application to a landlord
    final response = await http.post(
      Uri.parse('${ApiClass().getApiBaseUrl()}/apply-accommodation/'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'accommodation_id': widget.accommodation['id']}),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      _showSnackBar(
        "Application submitted successfully! WOW! 🎉",
        Colors.green,
      );
      Navigator.pop(context); // Go back home
    } else {
      throw Exception("Failed to submit application.");
    }
  }

  void _showLoginPrompt() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(
        0.6,
      ), // Darken the background slightly
      builder: (ctx) {
        final theme = Theme.of(context);
        final primary = theme.colorScheme.primary;

        return Dialog(
          backgroundColor:
              Colors.transparent, // Required for the glass effect to work
          elevation: 0,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: primary.withOpacity(0.2),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.lock_person_rounded,
                        size: 40,
                        color: primary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      "Authentication Required",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "You need to be securely logged in to apply for this residence and manage your applications.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.4,
                        color: theme.colorScheme.onSecondary,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: () => Navigator.pop(ctx),
                            child: Text(
                              "Cancel",
                              style: TextStyle(
                                color: theme.colorScheme.onSecondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              elevation: 10,
                              shadowColor: primary.withOpacity(0.4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: () {
                              Navigator.pop(ctx);
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const LoginScreen(),
                                ),
                              );
                            },
                            child: const Text(
                              "Login",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showDocumentUploadSheet(bool hasId, bool hasProof) {
    File? idFile;
    File? proofFile;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            final theme = Theme.of(context);
            final primary = theme.colorScheme.primary;

            Future<void> pickFile(bool isId) async {
              FilePickerResult? result = await FilePicker.pickFiles(
                type: FileType.custom,
                allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
              );
              if (result != null && result.files.single.path != null) {
                setModalState(() {
                  if (isId)
                    idFile = File(result.files.single.path!);
                  else
                    proofFile = File(result.files.single.path!);
                });
              }
            }

            Future<void> uploadDocs() async {
              if ((!hasId && idFile == null) ||
                  (!hasProof && proofFile == null)) {
                _showSnackBar(
                  "Please select the missing documents.",
                  Colors.redAccent,
                );
                return;
              }

              final user = FirebaseAuth.instance.currentUser;
              if (user == null) return;
              final token = await user.getIdToken();

              Navigator.pop(ctx); // Close sheet
              setState(() => _isProcessing = true);

              try {
                // Endpoint to update student profile with documents
                var request = http.MultipartRequest(
                  'POST',
                  Uri.parse(
                    '${ApiClass().getApiBaseUrl()}/students/update-documents/',
                  ),
                );
                request.headers['Authorization'] = 'Bearer $token';

                if (idFile != null) {
                  request.files.add(
                    await http.MultipartFile.fromPath(
                      'id_document',
                      idFile!.path,
                    ),
                  );
                }
                if (proofFile != null) {
                  request.files.add(
                    await http.MultipartFile.fromPath(
                      'proof_of_registration',
                      proofFile!.path,
                    ),
                  );
                }

                var streamedResponse = await request.send();
                if (streamedResponse.statusCode == 200 ||
                    streamedResponse.statusCode == 201) {
                  _showSnackBar(
                    "Documents uploaded securely! Processing application...",
                    Colors.green,
                  );
                  await _submitApplication(token!); // Auto proceed to apply
                } else {
                  throw Exception("Document upload failed.");
                }
              } catch (e) {
                _showSnackBar(e.toString(), Colors.redAccent);
              } finally {
                setState(() => _isProcessing = false);
              }
            }

            return ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(40),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                    top: 32,
                    left: 24,
                    right: 24,
                  ),
                  decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor.withOpacity(0.8),
                    border: Border(
                      top: BorderSide(color: primary.withOpacity(0.3)),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.folder_shared_rounded,
                        size: 48,
                        color: primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Missing Documents',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'To maintain community security, please upload your verification documents before applying.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: theme.colorScheme.onSecondary),
                      ),
                      const SizedBox(height: 32),

                      if (!hasId) ...[
                        _buildUploadButton(
                          'Upload ID Document',
                          idFile,
                          () => pickFile(true),
                          theme,
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (!hasProof) ...[
                        _buildUploadButton(
                          'Proof of Registration',
                          proofFile,
                          () => pickFile(false),
                          theme,
                        ),
                        const SizedBox(height: 32),
                      ],

                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: uploadDocs,
                          child: const Text(
                            'UPLOAD & APPLY',
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
            );
          },
        );
      },
    );
  }

  Widget _buildUploadButton(
    String title,
    File? file,
    VoidCallback onTap,
    ThemeData theme,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: file != null
                ? Colors.green
                : theme.colorScheme.primary.withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(
              file != null ? Icons.check_circle : Icons.upload_file,
              color: file != null
                  ? Colors.green
                  : theme.colorScheme.onSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                file != null ? file.path.split('/').last : title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final acc = widget.accommodation;
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final imageUrl =
        acc['accommodation_logo_url'] ??
        'https://images.unsplash.com/photo-1555854877-bab0e564b8d5?q=80&w=1000&auto=format&fit=crop';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 400,
                pinned: true,
                backgroundColor: theme.scaffoldBackgroundColor,
                leading: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        color: Colors.black.withOpacity(0.2),
                        child: IconButton(
                          icon: const Icon(
                            Icons.arrow_back_ios_new,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Hero(
                    tag: 'acc_image_${acc['id']}',
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(imageUrl, fit: BoxFit.cover),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                theme.scaffoldBackgroundColor,
                              ],
                              stops: const [0.6, 1.0],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    24,
                    0,
                    24,
                    100,
                  ), // padding bottom for action bar
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              acc['name'] ?? 'Residence',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              acc['gender_target'] ?? 'MIXED',
                              style: TextStyle(
                                color: primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            color: theme.colorScheme.onSecondary,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              acc['address'] ?? 'Address unlisted',
                              style: TextStyle(
                                color: theme.colorScheme.onSecondary,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'About',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        acc['description'] ??
                            'No description provided by the landlord.',
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.5,
                          color: theme.colorScheme.onSecondary,
                        ),
                      ),
                      const SizedBox(height: 32),
                      if (acc['key_price'] != null) ...[
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: primary.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: primary.withOpacity(0.2)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: primary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.key,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Key Deposit',
                                    style: TextStyle(
                                      color: theme.colorScheme.onSecondary,
                                    ),
                                  ),
                                  Text(
                                    'R ${acc['key_price']}',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Glassmorphism Bottom Action Bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 24,
                  ),
                  decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor.withOpacity(0.7),
                    border: Border(
                      top: BorderSide(color: primary.withOpacity(0.2)),
                    ),
                  ),
                  child: SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 10,
                        shadowColor: primary.withOpacity(0.5),
                      ),
                      onPressed: _isProcessing ? null : _handleApply,
                      child: _isProcessing
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'APPLY NOW',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                              ),
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
}
