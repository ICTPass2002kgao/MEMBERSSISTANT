import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:mobile_app/components/api_class.dart'; // Ensure this path matches your project structure

// This must be a top-level function (outside of any class) to work in the background.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you need to initialize Firebase here, do it, but usually the native side handles it.
  debugPrint("Handling a background message: ${message.messageId}");
}

class PushNotificationService {
  // Singleton pattern so we only ever have one instance of this service
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  // A broadcast stream controller allows multiple pages to listen at the same time
  final StreamController<RemoteMessage> _messageStreamController = 
      StreamController<RemoteMessage>.broadcast();

  // Expose the stream for your UI pages to listen to
  Stream<RemoteMessage> get onMessageStream => _messageStreamController.stream;

  Future<void> initialize() async {
    // 1. Request permissions (Crucial for iOS)
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    
    debugPrint('User granted permission: ${settings.authorizationStatus}');

    // 2. Register background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 3. Listen for messages while the app is in the foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Received foreground message: ${message.notification?.title}');
      // Broadcast the message to any listening UI pages
      _messageStreamController.add(message);
    });

    // 4. Handle notification taps when the app is in the background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('Notification clicked! Opened app from background.');
      // You can add routing logic here later if needed
    });

    // 5. Check if the app was opened from a terminated state via a notification
    RemoteMessage? initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('App launched from terminated state via notification.');
    }
  }

  // Sync the token to the Django backend for Direct Select messages
  Future<void> syncTokenToBackend() async {
    String? token = await getDeviceToken();
    if (token == null) {
      debugPrint("No FCM token generated.");
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint("No authenticated user to sync token with.");
      return;
    }

    try {
      final idToken = await user.getIdToken();
      final response = await http.post(
        Uri.parse('${ApiClass().getApiBaseUrl()}/update-fcm-token/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({'fcm_token': token}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint("FCM Token synced to Django successfully.");
      } else {
        debugPrint("Failed to sync token to Django: ${response.body}");
      }
    } catch (e) {
      debugPrint("Error syncing token to backend: $e");
    }
  }

  // Get the device token from Firebase
  Future<String?> getDeviceToken() async {
    try {
      return await _messaging.getToken();
    } catch (e) {
      debugPrint("Failed to get FCM token: $e");
      return null;
    }
  }

  void dispose() {
    _messageStreamController.close();
  }
}