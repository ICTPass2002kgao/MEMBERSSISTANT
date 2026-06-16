import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class ApiClass {
  String getApiBaseUrl() {
    // if (kIsWeb) {
    //   return 'http://127.0.0.1:8000/api'; // Localhost for Web Browser
    // } else if (Platform.isAndroid)
    //   return 'http://10.0.2.2:8000/api';
    // else if (Platform.isIOS)
    //   // Replace with the 172.20.10.X address you found
    //   return 'http://172.20.10.5:8000/api';
    // return 'http://127.0.0.1:8000/api';
    return "https://memberssistant.up.railway.app/api";
  }
/// Takes an encrypted Firebase URL and returns a decrypted, ready-to-use URL.
  String getDecryptedImageUrl(String encryptedFaceUrl, String idToken) {
    // We must encode the Firebase URL so it doesn't break the HTTP request
    final encodedUrl = Uri.encodeComponent(encryptedFaceUrl);
    return '${getApiBaseUrl()}/serve-decrypted-file/?file_url=$encodedUrl&token=$idToken';
  }
  static const String mapboxToken =
      "pk.eyJ1Ijoia2dhb2dlbG8tMjAyNiIsImEiOiJjbXEwMnlpdjYwMms0MnBxM2x3M3k5cXRrIn0.DRHm1nrq0nQ55-PIWamEhw";
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
