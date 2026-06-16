import 'package:flutter/foundation.dart'; // Required for kIsWeb
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:mobile_app/components/api_class.dart';
import 'package:mobile_app/firebase_options.dart';
import 'package:mobile_app/auth/login.dart';
import 'package:mobile_app/student_screens/tabs/components/push_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // 1. Initialize Firebase
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform); 

    // 2. Initialize Mapbox (MOBILE ONLY)
    if (!kIsWeb) {
    MapboxOptions.setAccessToken(ApiClass.mapboxToken);
    } else {
      debugPrint("Running on Web: Skipping Mapbox initialization.");
    }
    
    // 3. Initialize Push Notifications
    final pushService = PushNotificationService();
    await pushService.initialize();

    // If everything succeeds, run the actual app
    runApp(const MyApp());

  } catch (e, stackTrace) {
    debugPrint("CRITICAL INITIALIZATION ERROR: $e");
    
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.white,
          body: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Center(
              child: Text(
                "App Initialization Failed\n$e",
                style: const TextStyle(fontSize: 16, color: Colors.red),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color.fromARGB(255, 236, 239, 255),  
        colorScheme: const ColorScheme.dark(
          primary: Color.fromARGB(255, 35, 46, 132),  
          surface: Color.fromARGB(255, 235, 237, 247), 
          onSurface: Color.fromARGB(255, 35, 46, 132),  
          onSecondary: Color(0xFF94A3B8),  
        ),
      ),
      initialRoute: '/',
      routes: {'/': (context) => const LoginScreen()},
    );
  }
}