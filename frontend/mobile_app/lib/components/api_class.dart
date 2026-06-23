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
      final url = Uri.parse(
        'https://api-w6yanm6o4q-uc.a.run.app/sendCustomEmail',
      );
      final int currentYear = DateTime.now().year;

      // Convert raw message line breaks to HTML line breaks for correct rendering
      final String formattedMessage = message.replaceAll('\n', '<br/>');

      // Premium, compact HTML structure optimized for desktop and mobile email clients
      final String htmlBody = """
<div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; max-width: 550px; margin: 0 auto; background-color: #020617; padding: 16px; border-radius: 24px;">
<div style="background-color: #0f172a; border: 1px solid #1e293b; border-radius: 18px; overflow: hidden; box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);">

<!-- Header Section -->
<div style="padding: 16px 20px; border-bottom: 1px solid #1e293b; background: linear-gradient(to right, #0f172a, #1e293b); text-align: left;">
<table border="0" cellpadding="0" cellspacing="0" width="100%">
<tr>
<td>
<img src="https://firebasestorage.googleapis.com/v0/b/membersisstant.firebasestorage.app/o/FCMImages%2Fmemberssistant_icon.png?alt=media&token=01c986f2-5504-497b-bd75-e271edb4abf7" alt="Memberssistant Logo" style="max-height: 45px; margin-bottom: 10px; border-radius: 6px; display: block;">
<h1 style="color: #ffffff; margin: 0; font-size: 18px; font-weight: 800; letter-spacing: 0.5px;">Memberssistant</h1>
<p style="color: #64748b; margin: 2px 0 0 0; font-size: 11px; font-weight: 700; letter-spacing: 1px; text-transform: uppercase;">System Notification</p>
</td>
</tr>
</table>
</div>

<!-- Content Body Section -->
<div style="padding: 20px; color: #f1f5f9; background-color: #0f172a;">
<h2 style="color: #3b82f6; margin-top: 0; margin-bottom: 12px; font-size: 15px; font-weight: 700; letter-spacing: 0.3px;">\${title.toUpperCase()}</h2>
<div style="font-size: 14px; line-height: 1.5; color: #cbd5e1; margin: 0;">
\ $formattedMessage
</div>
</div>

<!-- Compact Interactive & Navigation Footer -->
<div style="padding: 16px 20px; background-color: #090d16; border-top: 1px solid #1e293b; text-align: center;">
<table border="0" cellpadding="0" cellspacing="0" width="100%">
<tr>
<td style="padding-bottom: 12px;">
<a href="https://mst.mktechcloud.co.za/terms-and-conditions" style="color: #94a3b8; text-decoration: none; font-size: 11px; font-weight: 600; margin: 0 8px; display: inline-block;">Terms & Conditions</a>
<span style="color: #334155; font-size: 11px;">•</span>
<a href="https://mst.mktechcloud.co.za/privacy-policy" style="color: #94a3b8; text-decoration: none; font-size: 11px; font-weight: 600; margin: 0 8px; display: inline-block;">Privacy Policy</a>
<span style="color: #334155; font-size: 11px;">•</span>
<a href="https://mst.mktechcloud.co.za/contact-support" style="color: #3b82f6; text-decoration: none; font-size: 11px; font-weight: 700; margin: 0 8px; display: inline-block;">Contact Us</a>
</td>
</tr>
<tr>
<td style="border-top: 1px solid #1e293b; padding-top: 12px;">
<p style="margin: 0; color: #475569; font-size: 10px; font-weight: 500; letter-spacing: 0.2px;">&copy: $currentYear MK TECHCLOUD (Pty) Ltd. All rights reserved.</p>
<p style="margin: 4px 0 0 0; color: #475569; font-size: 9px;">Automated operational transmission. Please do not reply directly to this address.</p>
</td>
</tr>
</table>
</div>

</div>
</div>
""";

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "to": receiver,
          "subject": title,
          "body": htmlBody,
          "attachmentUrl": "",
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
