import 'dart:convert';
import 'dart:ui';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../components/api_class.dart';
import 'email_verification.dart';

// Responsive Bubble Background
class BubbleBackground extends StatelessWidget {
  const BubbleBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final size = MediaQuery.of(context).size;

    return Stack(
      children: [
        Positioned(
          top: size.height * -0.1,
          left: size.width * -0.15,
          child: Container(
            width: size.width * 0.7,
            height: size.width * 0.7,
            constraints: const BoxConstraints(
              minWidth: 250,
              minHeight: 250,
              maxWidth: 400,
              maxHeight: 400,
            ),
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
          bottom: size.height * -0.1,
          right: size.width * -0.2,
          child: Container(
            width: size.width * 0.8,
            height: size.width * 0.8,
            constraints: const BoxConstraints(
              minWidth: 320,
              minHeight: 320,
              maxWidth: 500,
              maxHeight: 500,
            ),
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
          top: size.height * 0.3,
          right: size.width * -0.1,
          child: Container(
            width: size.width * 0.4,
            height: size.width * 0.4,
            constraints: const BoxConstraints(
              minWidth: 140,
              minHeight: 140,
              maxWidth: 200,
              maxHeight: 200,
            ),
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

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _studentNoController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _surnameController = TextEditingController();
  final TextEditingController _idNumberController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  String _selectedGender = 'MALE';
  bool _isLoading = false;
  bool _obscureText = true;
  bool _agreedToTerms = false;

  File? _idDocument;
  File? _proofOfRegistration;
  File? _proofOfFunding; // Added state for Proof of Funding

  @override
  void dispose() {
    _studentNoController.dispose();
    _nameController.dispose();
    _surnameController.dispose();
    _idNumberController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

 Future<void> _pickDocument(String docType) async {
  try { 
    PlatformFile? file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );

    if (file != null && file.path != null) {
      setState(() {
        final selectedFile = File(file.path!);
        if (docType == 'id') {
          _idDocument = selectedFile;
        } else if (docType == 'proof') {
          _proofOfRegistration = selectedFile;
        } else if (docType == 'funding') {
          _proofOfFunding = selectedFile;
        }
      });
    }
  } catch (e) {
    debugPrint("Error picking document: $e");
    _showError("Failed to pick document. Please try again.");
  }
}
  void _showSnackBar(BuildContext context, String message, Color color) {
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

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.redAccent.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _handleRegister() async {
    final studentNo = _studentNoController.text.trim();
    final name = _nameController.text.trim();
    final surname = _surnameController.text.trim();
    final idNumber = _idNumberController.text.trim();
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (studentNo.isEmpty ||
        name.isEmpty ||
        surname.isEmpty ||
        idNumber.isEmpty ||
        email.isEmpty ||
        password.isEmpty) {
      _showError('Please fill in all required text fields.');
      return;
    }

    if (idNumber.length != 13) {
      _showError('Please provide a valid Identification Number.');
      return;
    }

    if (!_agreedToTerms) {
      _showError('Please accept the Terms & Conditions and Privacy Policy.');
      return;
    }

    setState(() => _isLoading = true);

    // 1. Generate OTP and send email before submitting data
    String otp = (Random().nextInt(900000) + 100000).toString();

    ApiClass().sendEmail(
      email,
      "Verification Code",
      "Hello $name $surname,\n\nYour 6-digit verification code is: $otp\n\nThis code expires soon.",
    );

    setState(() => _isLoading = false);

    // 2. Navigate to OTP verification screen
    if (!mounted) return;
    bool? isVerified = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EmailVerificationScreen(
          email: email,
          expectedCode: otp,
          name: name,
        ),
      ),
    );

    // 3. If OTP succeeds, proceed with backend registration
    if (isVerified == true) {
      await _submitRegistrationData(
        studentNo,
        name,
        surname,
        idNumber,
        phone,
        email,
        password,
      );
    }
  }

  Future<void> _submitRegistrationData(
    String studentNo,
    String name,
    String surname,
    String idNumber,
    String phone,
    String email,
    String password,
  ) async {
    setState(() => _isLoading = true);

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiClass().getApiBaseUrl()}/student-self-register/'),
      );

      request.fields['student_number'] = studentNo;
      request.fields['name'] = name;
      request.fields['surname'] = surname;
      request.fields['id_number'] = idNumber;
      request.fields['password'] = password;
      request.fields['gender'] = _selectedGender;
      request.fields['phone'] = phone;
      request.fields['email'] = email;

      if (_idDocument != null) {
        request.files.add(
          await http.MultipartFile.fromPath('id_document', _idDocument!.path),
        );
      }

      if (_proofOfRegistration != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'proof_of_registration',
            _proofOfRegistration!.path,
          ),
        );
      }

      // FIX: Add the Proof of Funding file to the request
      if (_proofOfFunding != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'proof_of_funding',
            _proofOfFunding!.path,
          ),
        );
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201) {
        if (!mounted) return;
        _showSnackBar(
          context,
          'Registration successful! Please login.',
          Colors.green,
        );
        Navigator.pop(context); // Return to login state
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['error'] ?? 'Registration failed.');
      }
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final slateColor = theme.colorScheme.onSecondary;
    final textColor = theme.colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword ? _obscureText : false,
        keyboardType: keyboardType,
        style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
        cursorColor: primaryColor,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            color: slateColor,
            fontWeight: FontWeight.normal,
          ),
          filled: true,
          fillColor: primaryColor.withOpacity(0.05),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: primaryColor.withOpacity(0.5),
              width: 0.5,
            ),
          ),
          prefixIcon: Icon(icon, color: slateColor),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    _obscureText ? Icons.visibility_off : Icons.visibility,
                    color: slateColor,
                  ),
                  onPressed: () => setState(() => _obscureText = !_obscureText),
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildGenderDropdown() {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final slateColor = theme.colorScheme.onSecondary;
    final textColor = theme.colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: primaryColor.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
        ),
        child: DropdownButtonFormField<String>(
          value: _selectedGender,
          dropdownColor: theme.scaffoldBackgroundColor,
          icon: Icon(Icons.keyboard_arrow_down, color: slateColor),
          style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            border: InputBorder.none,
            prefixIcon: Icon(Icons.wc, color: slateColor),
          ),
          items: const [
            DropdownMenuItem(value: 'MALE', child: Text('Male')),
            DropdownMenuItem(value: 'FEMALE', child: Text('Female')),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _selectedGender = value;
              });
            }
          },
        ),
      ),
    );
  }

  // FIX: Changed 'bool isId' to 'String docType' to support 3 document types
  Widget _buildFilePicker(String title, File? file, String docType) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: InkWell(
        onTap: () => _pickDocument(docType),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: file != null
                  ? Colors.green
                  : primaryColor.withOpacity(0.2),
              width: 1,
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
                  file != null
                      ? file.path.split('/').last
                      : '$title (Optional)',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final textColor = theme.colorScheme.onSurface;
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 400; // Trigger for tiny mobile screens
    final isTabletOrWeb = size.width > 600; // Trigger for larger screens

    return Scaffold(
      body: Stack(
        children: [
          const BubbleBackground(),
          GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isTabletOrWeb ? 0 : 24.0,
                    vertical: 20.0,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 450),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(
                        isSmallScreen ? 32 : 52,
                      ),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: Container(
                          padding: EdgeInsets.all(isSmallScreen ? 24.0 : 32.0),
                          decoration: BoxDecoration(
                            color: theme.scaffoldBackgroundColor.withOpacity(
                              0.7,
                            ),
                            borderRadius: BorderRadius.circular(
                              isSmallScreen ? 32 : 52,
                            ),
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
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: primaryColor.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: primaryColor.withOpacity(0.3),
                                  ),
                                ),
                                child: Icon(
                                  Icons.person_add_alt_1_rounded,
                                  size: 40,
                                  color: primaryColor,
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'Register',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 22 : 24,
                                  fontWeight: FontWeight.w900,
                                  color: textColor,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Create your student profile',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 40),

                              _buildTextField(
                                controller: _studentNoController,
                                hintText: 'Student Number',
                                icon: Icons.numbers_rounded,
                                keyboardType: TextInputType.number,
                              ),
                              _buildTextField(
                                controller: _nameController,
                                hintText: 'First Name',
                                icon: Icons.person_outline,
                              ),
                              _buildTextField(
                                controller: _surnameController,
                                hintText: 'Surname',
                                icon: Icons.badge_outlined,
                              ),
                              _buildTextField(
                                controller: _idNumberController,
                                hintText: 'ID / Passport Number',
                                icon: Icons.assignment_ind_outlined,
                                keyboardType: TextInputType.phone,
                              ),
                              _buildTextField(
                                controller: _phoneController,
                                hintText: 'Phone Number',
                                icon: Icons.phone_outlined,
                                keyboardType: TextInputType.phone,
                              ),
                              _buildTextField(
                                controller: _emailController,
                                hintText: 'Email Address',
                                icon: Icons.email_outlined,
                                keyboardType: TextInputType.emailAddress,
                              ),
                              _buildGenderDropdown(),
                              _buildTextField(
                                controller: _passwordController,
                                hintText: 'Password',
                                icon: Icons.lock_outline,
                                isPassword: true,
                              ),

                              const Divider(height: 32),

                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Verification Documents',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onSecondary,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              
                              // FIX: Updated to pass Strings instead of booleans
                              _buildFilePicker(
                                'Upload ID Document',
                                _idDocument,
                                'id',
                              ),
                              _buildFilePicker(
                                'Proof of Registration',
                                _proofOfRegistration,
                                'proof',
                              ),
                              // FIX: Added the third file picker for Funding
                              _buildFilePicker(
                                'Proof of Funding',
                                _proofOfFunding,
                                'funding',
                              ),

                              const SizedBox(height: 20),

                              // Checkbox and Links
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: Checkbox(
                                      value: _agreedToTerms,
                                      onChanged: (val) {
                                        setState(() {
                                          _agreedToTerms = val ?? false;
                                        });
                                      },
                                      activeColor: primaryColor,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: RichText(
                                      text: TextSpan(
                                        style: TextStyle(
                                          color: theme.colorScheme.onSecondary,
                                          fontSize: 13,
                                          height: 1.4,
                                        ),
                                        children: [
                                          const TextSpan(
                                            text:
                                                "I have read and agree to the ",
                                          ),
                                          WidgetSpan(
                                            child: GestureDetector(
                                              onTap: () async {
                                                final Uri url = Uri.parse(
                                                  "https://mst.mktechcloud.co.za/terms-and-conditions",
                                                );
                                                if (!await launchUrl(
                                                  url,
                                                  mode: LaunchMode
                                                      .inAppBrowserView,
                                                )) {
                                                  debugPrint(
                                                    "Could not launch T&C url",
                                                  );
                                                }
                                              },
                                              child: Text(
                                                "Terms and Conditions",
                                                style: TextStyle(
                                                  color: primaryColor,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const TextSpan(text: " and the "),
                                          WidgetSpan(
                                            child: GestureDetector(
                                              onTap: () async {
                                                final Uri url = Uri.parse(
                                                  "https://mst.mktechcloud.co.za/privacy-policy",
                                                );
                                                if (!await launchUrl(
                                                  url,
                                                  mode: LaunchMode
                                                      .inAppBrowserView,
                                                )) {
                                                  debugPrint(
                                                    "Could not launch Privacy Policy url",
                                                  );
                                                }
                                              },
                                              child: Text(
                                                "Privacy Policy.",
                                                style: TextStyle(
                                                  color: primaryColor,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 24),

                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: _isLoading
                                      ? null
                                      : _handleRegister,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryColor,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 8,
                                    shadowColor: primaryColor.withOpacity(0.5),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text(
                                          'CREATE ACCOUNT',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 2,
                                          ),
                                        ),
                                ),
                              ),

                              const SizedBox(height: 16),

                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text(
                                  'Already have an account? Login',
                                  style: TextStyle(
                                    color: primaryColor,
                                    fontWeight: FontWeight.bold,
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
            ),
          ),
        ],
      ),
    );
  }
}