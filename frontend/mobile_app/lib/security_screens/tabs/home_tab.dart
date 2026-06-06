import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class SecurityHomeTab extends StatelessWidget {
  final String name;
  final String role;
  final String initials;
  final Function(int) onNavigate;
  final VoidCallback onLogout;

  const SecurityHomeTab({
    super.key,
    required this.name,
    required this.role,
    required this.initials,
    required this.onNavigate,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final slateColor = theme.colorScheme.onSecondary;
    final textColor = theme.colorScheme.onSurface;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Active Shift,',
                    style: TextStyle(
                      color: slateColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: textColor,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap:
                    onLogout, // In a real app, open a profile modal here instead
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: primaryColor.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: primaryColor.withOpacity(0.15),
                    child: Text(
                      initials.toUpperCase(),
                      style: TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Core Action Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: primaryColor,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    role.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Gate Control',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Scan Exit Permits',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: () => onNavigate(1), // Open Scanner
                    icon: const Icon(
                      CupertinoIcons.qrcode_viewfinder,
                      color: Colors.black87,
                    ),
                    label: const Text(
                      'LAUNCH SCANNER',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Colors.black87,
                        letterSpacing: 1.0,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    role.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Gate Control',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Scan Gate Pass',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: () => onNavigate(1), // Open Scanner
                    icon: const Icon(
                      CupertinoIcons.qrcode_viewfinder,
                      color: Colors.black87,
                    ),
                    label: const Text(
                      'LAUNCH SCANNER',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Colors.black87,
                        letterSpacing: 1.0,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
