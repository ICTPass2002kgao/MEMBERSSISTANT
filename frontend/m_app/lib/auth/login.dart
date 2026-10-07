import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'responder-login.dart';
import '../components/api_class.dart';
import '../attendant_screens/tabs/dashboard.dart';
import 'landlord_verify.dart';
import 'register_screen.dart';
import '../security_screens/tabs/dashboard.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../student_screens/tabs/components/push_notification_service.dart';

import '../student_screens/tabs/main_menu.dart';
import 'forgot_password.dart';

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

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _identifierController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscureText = true;
  bool _isCheckingAuth = true;

  @override
  void initState() {
    super.initState();
    _checkExistingLogin();

  }

  Future<void> _checkExistingLogin() async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser != null) {
      final prefs = await SharedPreferences.getInstance();
      final String? baseRole = prefs.getString('user_role');
      final String? userDataStr = prefs.getString('user_data');
      if(baseRole != null && userDataStr != null) {
        try {
          final Map<String, dynamic> userData = jsonDecode(userDataStr);

          await PushNotificationService().initialize(userRole: baseRole);
          await PushNotificationService().syncTokenToBackend();

          if (!mounted) return;

          if (baseRole == 'student') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const StudentMainMenu()),
            );
          } else if (baseRole == 'responder') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    ResponderFaceVerificationScreen(userData: userData),
              ),
            );
          } else if (baseRole == 'staff') {
            final String specificRole = userData['role'] ?? 'ATTENDANT';
            if (specificRole == 'SECURITY') {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const SecurityDashboard()),
              );
            } else {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const AttendantDashboard()),
              );
            }
          } else {
            prefs.clear();

             }
          return;
        } catch (e) {
          debugPrint("Auto-login error: $e");
        }
      }
 
    }

    if (mounted) {
      setState(() {
        _isCheckingAuth = false;
      });
    }
  }

  Future<void> _handleLogin() async {
    final identifier = _identifierController.text.trim();
    final password = _passwordController.text.trim();

    if (identifier.isEmpty || password.isEmpty) {
      _showError('Please fill in all fields.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      String loginEmail = identifier.contains('@')
          ? identifier
          : '$identifier@edu.vut.ac.za';

      final userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: loginEmail, password: password);

      final idToken = await userCredential.user?.getIdToken();
      if (idToken == null) throw Exception("Failed to retrieve secure token.");

      final response = await http.post(
        Uri.parse('${ApiClass().getApiBaseUrl()}/login/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id_token': idToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('fb_id_token', idToken);
        await prefs.setString('user_data', jsonEncode(data['user_data']));

        final String baseRole = data['role'];

        await PushNotificationService().initialize(userRole: baseRole);
        await PushNotificationService().syncTokenToBackend();

        if (!mounted) return;
        if (baseRole != "student") {
          await prefs.clear();
        }

        if (baseRole == 'student') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const StudentMainMenu()),
          );
        } else if (baseRole == 'responder') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ResponderFaceVerificationScreen(
                userData: data['user_data'] ?? {},
              ),
            ),
          );
        } else if (baseRole == 'staff') {
          final String specificRole = data['user_data']['role'] ?? 'ATTENDANT';
          if (specificRole == 'SECURITY') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const SecurityDashboard()),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const AttendantDashboard()),
            );
          }
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  LandlordVerificationScreen(userData: data['user_data'] ?? {}),
            ),
          );
        }
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['error'] ?? 'System verification failed.');
      }
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? 'Authentication failed. Check your credentials.');
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleAnonymousLogin() async {
    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.signInAnonymously();

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const StudentMainMenu()),
      );
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? 'Anonymous login failed.');
    } catch (e) {
      _showError(e.toString());
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final slateColor = theme.colorScheme.onSecondary;
    final textColor = theme.colorScheme.onSurface;
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 400; // Trigger for tiny mobile screens
    final isTabletOrWeb = size.width > 600; // Trigger for larger screens

    return Scaffold(
      body: Stack(
        children: [
          const BubbleBackground(),
          if (_isCheckingAuth)
            Center(child: CircularProgressIndicator(color: primaryColor))
          else
            GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: isTabletOrWeb ? 0 : 24.0,
                      vertical: 24.0,
                    ),
                    child: ConstrainedBox(
                      // Max width ensures the login form doesn't stretch on Tablets/Web
                      constraints: const BoxConstraints(maxWidth: 450),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                          isSmallScreen ? 32 : 52,
                        ),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                          child: Container(
                            padding: EdgeInsets.all(
                              isSmallScreen ? 24.0 : 32.0,
                            ),
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
                                    Icons.lock_outline_rounded,
                                    size: 40,
                                    color: primaryColor,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  'Memberssistant',
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 22 : 24,
                                    fontWeight: FontWeight.w900,
                                    color: textColor,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Resident & Staff Portal',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: primaryColor,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 40),

                                TextFormField(
                                  controller: _identifierController,
                                  style: TextStyle(
                                    color: textColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  cursorColor: primaryColor,
                                  decoration: InputDecoration(
                                    hintText: 'Student No. or Staff Email',
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
                                    prefixIcon: Icon(
                                      Icons.person_outline,
                                      color: slateColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),

                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: _obscureText,
                                  style: TextStyle(
                                    color: textColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  cursorColor: primaryColor,
                                  decoration: InputDecoration(
                                    hintText: 'Password',
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
                                        color: primaryColor.withOpacity(0.4),
                                        width: 0.5,
                                      ),
                                    ),
                                    prefixIcon: Icon(
                                      Icons.shield_outlined,
                                      color: slateColor,
                                    ),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscureText
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                        color: slateColor,
                                      ),
                                      onPressed: () => setState(
                                        () => _obscureText = !_obscureText,
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 12),

                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const ForgotPasswordScreen(),
                                        ),
                                      );
                                    },
                                    child: Text(
                                      'Forgot Password?',
                                      style: TextStyle(
                                        color: primaryColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 24),

                                SizedBox(
                                  width: double.infinity,
                                  height: 56,
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _handleLogin,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primaryColor,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      elevation: 8,
                                      shadowColor: primaryColor.withOpacity(
                                        0.5,
                                      ),
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
                                            'AUTHORIZE',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 2,
                                            ),
                                          ),
                                  ),
                                ),

                                const SizedBox(height: 16),

                                SizedBox(
                                  width: double.infinity,
                                  height: 56,
                                  child: OutlinedButton(
                                    onPressed: _isLoading
                                        ? null
                                        : _handleAnonymousLogin,
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: primaryColor,
                                      side: BorderSide(
                                        color: primaryColor,
                                        width: 1.5,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: const Text(
                                      'PROCEED WITHOUT LOGIN',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 16),

                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Don\'t have an account?',
                                      style: TextStyle(
                                        color: slateColor,
                                        fontWeight: FontWeight.normal,
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const RegisterScreen(),
                                          ),
                                        );
                                      },
                                      child: Text(
                                        'Sign Up',
                                        style: TextStyle(
                                          color: primaryColor,
                                          fontWeight: FontWeight.bold,
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
