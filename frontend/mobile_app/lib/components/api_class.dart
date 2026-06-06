import 'dart:io';

import 'package:flutter/material.dart';

class ApiClass {
  String getApiBaseUrl() {
    if (Platform.isAndroid)
      return 'http://10.0.2.2:8000/api';
    else if (Platform.isIOS)
      // Replace with the 172.20.10.X address you found
      return 'http://172.20.10.2:8000/api';
    return 'http://127.0.0.1:8000/api';
  }

  // Example in your Flutter app
  final String baseUrl = 'http://127.0.0.1:8000/api';
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
