import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:mobile_app/components/api_class.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("Handling a background message: ${message.messageId}");
}

class PushNotificationService {
  static final PushNotificationService _instance =
      PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  final StreamController<RemoteMessage> _messageStreamController =
      StreamController<RemoteMessage>.broadcast();

  Stream<RemoteMessage> get onMessageStream => _messageStreamController.stream;

  // Added flag to prevent duplicate listener registration if called multiple times
  bool _isInitialized = false;

  Future<void> initialize({String? userRole}) async {
    // 1. Request permissions
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint('User granted permission: ${settings.authorizationStatus}');

    // 2. Force iOS to show foreground notifications automatically
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // 3. Setup Android Local Notifications Channel for foreground popups
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings();

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );

    await _localNotifications.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('Notification tapped: ${response.payload}');
      },
    );

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'This channel is used for important notifications.',
      importance: Importance.max,
    );

    final androidImplementation = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    // Request Android 13+ specific notification permissions
    await androidImplementation?.requestNotificationsPermission();
    await androidImplementation?.createNotificationChannel(channel);

    // 4. Conditional Topic Subscriptions
    try {
      await _messaging.subscribeToTopic('all');

      if (userRole == 'student') {
        await _messaging.subscribeToTopic('students');
        await _messaging.unsubscribeFromTopic('attendants'); 
      } else if (userRole == 'attendant' ||
          userRole == 'staff' ||
          userRole == 'security') {
        await _messaging.subscribeToTopic('attendants');
        await _messaging.unsubscribeFromTopic('students');
      }

      debugPrint(
        '✅ Subscribed to global topics for role: ${userRole ?? "Guest"}',
      );
    } catch (e) {
      debugPrint('❌ Failed to subscribe to topics: $e');
    }

    // Wrap listeners in a check to prevent duplicates if initialize is called again at login
    if (!_isInitialized) {
      // 5. Register background handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // 6. Listen for messages while the app is in the foreground
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Received foreground message: ${message.notification?.title}');

        RemoteNotification? notification = message.notification;
        AndroidNotification? android = message.notification?.android;

        if (notification != null && android != null) {
          _localNotifications.show(
            id: notification.hashCode.abs(), // FIX: Prevents negative integer crashes
            title: notification.title,
            body: notification.body,
            notificationDetails: NotificationDetails(
              android: AndroidNotificationDetails(
                channel.id,
                channel.name,
                channelDescription: channel.description,
                importance: Importance.max,
                priority: Priority.high,
                icon: '@mipmap/ic_launcher',
              ),
            ),
          );
        }

        _messageStreamController.add(message);
      });

      // 7. Handle notification taps when the app is in the background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('Notification clicked! Opened app from background.');
      });

      // 8. Check if the app was opened from a terminated state via a notification
      RemoteMessage? initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('App launched from terminated state via notification.');
      }

      _isInitialized = true;
    }
  }

  Future<void> syncTokenToBackend() async {
    debugPrint("--- STARTING FCM TOKEN SYNC ---");

    String? token = await getDeviceToken();
    if (token == null) {
      debugPrint("❌ SYNC ABORTED: FCM token is null.");
      return;
    }
    debugPrint("✅ FCM Token retrieved: $token");

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint("❌ SYNC ABORTED: No authenticated user found.");
      return;
    }

    try {
      final idToken = await user.getIdToken(true);
      if (idToken == null) return;

      final url = Uri.parse('${ApiClass().getApiBaseUrl()}/update-fcm-token/');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({'fcm_token': token}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint("✅ FCM Token synced successfully.");
      } else {
        debugPrint("❌ Failed to sync. Status: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("❌ CRITICAL ERROR during token sync: $e");
    }
  }

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