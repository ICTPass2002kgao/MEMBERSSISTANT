import 'dart:convert';
import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_app/components/api_class.dart';

// Reused internal aesthetic to match your login/register screen style without needing external components
class _BubbleBackground extends StatelessWidget {
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
      ],
    );
  }
}

class EmailVerificationScreen extends StatefulWidget {
  final String email;
  final String name;
  final String expectedCode;

  const EmailVerificationScreen({
    Key? key,
    required this.email,
    required this.name,
    required this.expectedCode,
  }) : super(key: key);

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());

  String? _errorMessage;
  bool _isLoading = false;
  late String _currentExpectedCode;

  @override
  void initState() {
    super.initState();
    _currentExpectedCode = widget.expectedCode;
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  String get _currentCode {
    return _controllers.map((c) => c.text).join();
  }

  void _verifyCode() async {
    for (var node in _focusNodes) {
      node.unfocus();
    }

    String code = _currentCode;
    if (code.length != 6) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    await Future.delayed(const Duration(seconds: 1)); // Small UX delay

    if (code == _currentExpectedCode) {
      if (mounted) {
        // Return true back to the registration screen to execute the actual HTTP post
        Navigator.pop(context, true);
      }
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = "Wrong code, please try again.";
        for (var controller in _controllers) {
          controller.clear();
        }
      });
      _focusNodes[0].requestFocus();
    }
  }

  Future<void> _resendCode() async {
    setState(() => _isLoading = true);

    String newCode = (Random().nextInt(900000) + 100000).toString();

    try {
      ApiClass().sendEmail(
        widget.email,
        "Resend: Your Registration Verification Code",
        "Hello ${widget.name},\n\nYour new 6-digit verification code is: $newCode\n\nThis code expires soon.",
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('A new code has been sent to your email.'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Failed to resend email. Please check your connection.',
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      body: Stack(
        children: [
          _BubbleBackground(),
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 20.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context, false),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.scaffoldBackgroundColor.withOpacity(0.7),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: primaryColor.withOpacity(0.2),
                          ),
                        ),
                        child: Icon(Icons.arrow_back, color: primaryColor),
                      ),
                    ),
                    const SizedBox(height: 40),

                    ClipRRect(
                      borderRadius: BorderRadius.circular(40),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: Container(
                          padding: const EdgeInsets.all(32.0),
                          decoration: BoxDecoration(
                            color: theme.scaffoldBackgroundColor.withOpacity(
                              0.8,
                            ),
                            borderRadius: BorderRadius.circular(40),
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
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: primaryColor.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: primaryColor.withOpacity(0.3),
                                  ),
                                ),
                                child: Icon(
                                  Icons.mark_email_read_outlined,
                                  size: 45,
                                  color: primaryColor,
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'Verification',
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  color: theme.colorScheme.onSurface,
                                  letterSpacing: 1.2,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Enter the 6-digit code we sent to:',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: theme.colorScheme.onSecondary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                widget.email,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                ),
                              ),
                              const SizedBox(height: 35),

                              // OTP INPUTS
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: List.generate(6, (index) {
                                  return SizedBox(
                                    width: 45,
                                    height: 55,
                                    child: KeyboardListener(
                                      focusNode: FocusNode(),
                                      onKeyEvent: (event) {
                                        if (event is KeyDownEvent &&
                                            event.logicalKey ==
                                                LogicalKeyboardKey.backspace) {
                                          if (_controllers[index]
                                                  .text
                                                  .isEmpty &&
                                              index > 0) {
                                            _focusNodes[index - 1]
                                                .requestFocus();
                                          }
                                        }
                                      },
                                      child: TextFormField(
                                        controller: _controllers[index],
                                        focusNode: _focusNodes[index],
                                        autofocus: index == 0,
                                        textAlign: TextAlign.center,
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [
                                          FilteringTextInputFormatter
                                              .digitsOnly,
                                        ],
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: primaryColor,
                                        ),
                                        decoration: InputDecoration(
                                          counterText: "",
                                          filled: true,
                                          fillColor: primaryColor.withOpacity(
                                            0.08,
                                          ),
                                          contentPadding: EdgeInsets.zero,
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            borderSide: BorderSide.none,
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            borderSide: BorderSide(
                                              color: primaryColor,
                                              width: 1.5,
                                            ),
                                          ),
                                        ),
                                        onChanged: (value) {
                                          if (_errorMessage != null) {
                                            setState(
                                              () => _errorMessage = null,
                                            );
                                          }
                                          if (value.length == 6) {
                                            for (int i = 0; i < 6; i++) {
                                              _controllers[i].text = value[i];
                                            }
                                            _verifyCode();
                                          } else if (value.length == 1) {
                                            if (index < 5) {
                                              FocusScope.of(
                                                context,
                                              ).requestFocus(
                                                _focusNodes[index + 1],
                                              );
                                            } else {
                                              _focusNodes[index].unfocus();
                                              _verifyCode();
                                            }
                                          } else if (value.length > 1) {
                                            _controllers[index].text = value
                                                .substring(value.length - 1);
                                            if (index < 5) {
                                              FocusScope.of(
                                                context,
                                              ).requestFocus(
                                                _focusNodes[index + 1],
                                              );
                                            }
                                          } else if (value.isEmpty) {
                                            if (index > 0) {
                                              FocusScope.of(
                                                context,
                                              ).requestFocus(
                                                _focusNodes[index - 1],
                                              );
                                            }
                                          }
                                        },
                                      ),
                                    ),
                                  );
                                }),
                              ),

                              const SizedBox(height: 20),

                              if (_errorMessage != null)
                                Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                    color: Colors.redAccent,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),

                              const SizedBox(height: 30),

                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: _isLoading
                                      ? null
                                      : () {
                                          if (_currentCode.length == 6) {
                                            _verifyCode();
                                          }
                                        },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryColor,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 6,
                                    shadowColor: primaryColor.withOpacity(0.5),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          height: 24,
                                          width: 24,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text(
                                          'VERIFY ACCOUNT',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.5,
                                          ),
                                        ),
                                ),
                              ),

                              const SizedBox(height: 20),

                              TextButton(
                                onPressed: _isLoading ? null : _resendCode,
                                child: Text(
                                  "Didn't receive the code? Resend",
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
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
