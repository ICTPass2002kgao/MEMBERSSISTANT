import 'package:flutter/material.dart';

/// A reusable base container for the Neumorphic effect
class NeumorphicContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final double? width;
  final double? height;

  const NeumorphicContainer({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = 15.0,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final surfaceColor = colorScheme.surface; 

    return Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: const [
          // Dark drop shadow
          BoxShadow(
            color: Color(0xFF1A1C20), // Calculated dark shadow for 0xFF2A2D32
            offset: Offset(6, 6),
            blurRadius: 12,
          ),
          // Light highlight
          BoxShadow(
            color: Color(0xFF3A3E44), // Calculated light highlight for 0xFF2A2D32
            offset: Offset(-6, -6),
            blurRadius: 12,
          ),
        ],
      ),
      child: child,
    );
  }
}

/// A reusable Neumorphic TextField
class NeumorphicTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final bool obscureText;

  const NeumorphicTextField({
    super.key,
    required this.controller,
    required this.hintText,
    this.obscureText = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return NeumorphicContainer(
      borderRadius: 10.0,
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        style: TextStyle(color: colorScheme.onSurface),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: colorScheme.onSecondary.withOpacity(0.5)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }
}

/// A reusable Neumorphic Button
class NeumorphicButton extends StatelessWidget {
  final VoidCallback? onTap;
  final String text;
  final bool isLoading;

  const NeumorphicButton({
    super.key,
    required this.onTap,
    required this.text,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: NeumorphicContainer(
        width: double.infinity,
        height: 55,
        borderRadius: 10.0,
        child: Center(
          child: isLoading
              ? SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    color: colorScheme.primary,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  text,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
        ),
      ),
    );
  }
}