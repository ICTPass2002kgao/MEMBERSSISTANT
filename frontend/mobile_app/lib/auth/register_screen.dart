import 'dart:convert';
import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:mobile_app/components/api_class.dart';

// Reuse your exact background widget
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
  final TextEditingController _phoneController =
      TextEditingController(); // Added Phone
  final TextEditingController _passwordController = TextEditingController();

  String _selectedGender = 'MALE'; // Added Gender default

  bool _isLoading = false;
  bool _obscureText = true;

  File? _idDocument;
  File? _proofOfRegistration;

  Future<void> _pickDocument(bool isId) async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        if (isId) {
          _idDocument = File(result.files.single.path!);
        } else {
          _proofOfRegistration = File(result.files.single.path!);
        }
      });
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

  Future<void> _handleRegister() async {
    final studentNo = _studentNoController.text.trim();
    final name = _nameController.text.trim();
    final surname = _surnameController.text.trim();
    final idNumber = _idNumberController.text.trim();
    final phone = _phoneController.text.trim(); // Capture Phone
    final password = _passwordController.text.trim();

    if (studentNo.isEmpty ||
        name.isEmpty ||
        surname.isEmpty ||
        idNumber.isEmpty ||
        password.isEmpty) {
      _showError('Please fill in all required text fields.');
      return;
    }

    if (idNumber.length != 13) {
      _showError('Please provide a valid Identification Number.');
      return;
    }

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
      request.fields['gender'] = _selectedGender; // Send Gender
      request.fields['phone'] = phone; // Send Phone if provided
  

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

  // Added Custom Dropdown for Gender
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

  Widget _buildFilePicker(String title, File? file, bool isId) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: InkWell(
        onTap: () => _pickDocument(isId),
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

    return Scaffold(
      body: Stack(
        children: [
          const BubbleBackground(),
          GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 20.0,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(52),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        padding: const EdgeInsets.all(32.0),
                        decoration: BoxDecoration(
                          color: theme.scaffoldBackgroundColor.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(52),
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
                                fontSize: 24,
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
                              keyboardType: TextInputType.text,
                            ),
                            _buildTextField(
                              controller: _phoneController,
                              hintText: 'Phone Number',
                              icon: Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                            ),
                            _buildGenderDropdown(), // Injected Gender Selector
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
                            _buildFilePicker(
                              'Upload ID Document',
                              _idDocument,
                              true,
                            ),
                            _buildFilePicker(
                              'Proof of Registration',
                              _proofOfRegistration,
                              false,
                            ),

                            const SizedBox(height: 24),

                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _handleRegister,
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
        ],
      ),
    );
  }
}
