import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login.dart'; // To reuse the BubbleBackground

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _identifierController = TextEditingController();
  bool _isLoading = false;

  Future<void> _handleReset() async {
    final identifier = _identifierController.text.trim();

    if (identifier.isEmpty) {
      _showMessage('Please enter your Student Number or Email.', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try { 
      String resetEmail = identifier.contains('@')
          ? identifier
          : '$identifier@edu.vut.ac.za';

      await FirebaseAuth.instance.sendPasswordResetEmail(email: resetEmail);

      _showMessage(
        'Password reset link sent! Check your email.',
        isError: false,
      ); 
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      _showMessage(e.message ?? 'Failed to send reset email.', isError: true);
    } catch (e) {
      _showMessage(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMessage(String message, {required bool isError}) {
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
        backgroundColor: isError
            ? Colors.redAccent.shade400
            : Colors.green.shade500,
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

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: Stack(
        children: [
          const BubbleBackground(), 
           GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Container(
                    padding: const EdgeInsets.all(32.0),
                    decoration: BoxDecoration(
                      color: theme.scaffoldBackgroundColor.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
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
                            color: Colors.orange.withOpacity(0.1),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.orange.withOpacity(0.3),
                            ),
                          ),
                          child: const Icon(
                            Icons.lock_reset_rounded,
                            size: 40,
                            color: Colors.orange,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Reset Password',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: textColor,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Enter your Student Number or Staff Email. We will send a secure reset link to your registered email.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: slateColor,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 32),

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
                                color: primaryColor.withOpacity(0.4),
                                width: 0.5,
                              ),
                            ),
                            prefixIcon: Icon(
                              Icons.email_outlined,
                              color: slateColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleReset,
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
                                    'SEND RESET LINK',
                                    style: TextStyle(
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
