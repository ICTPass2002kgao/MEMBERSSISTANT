import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;


class ApiClass {
  String getApiBaseUrl() {
    // if (kIsWeb) {
    //   return 'http://127.0.0.1:8000/api'; // Localhost for Web Browser
    // } else if (Platform.isAndroid)
    //   return 'http://10.0.2.2:8000/api';
    // else if (Platform.isIOS)
    //   // Replace with the 172.20.10.X address you found
    //   return 'http://172.20.10.8:8000/api';
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

      Future<bool> sendEmail(String receiver, String title, String message) async {
    try {
      final url = Uri.parse('https://api-w6yanm6o4q-uc.a.run.app/sendCustomEmail');

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "to": receiver,
          "subject": title,
          "body": message,
          "attachmentUrl": "", // Left blank as per your previous endpoint requirements
        }),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        print('Email failed with status: ${response.statusCode}');
        print('Response body: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Exception sending email: $e');
      return false;
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

}