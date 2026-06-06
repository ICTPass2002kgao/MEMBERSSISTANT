import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:mobile_app/firebase_options.dart';
import 'package:mobile_app/auth/login.dart';
import 'package:mobile_app/student_screens/tabs/components/push_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform); 
MapboxOptions.setAccessToken("pk.eyJ1IjoieW91cm5hbWUiLCJhIjoiY2p4b... YOUR_TOKEN");
  // Initialize the reusable notification service
  final pushService = PushNotificationService();
  await pushService.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Color.fromARGB(255, 236, 239, 255),  
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
