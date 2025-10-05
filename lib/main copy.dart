import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'screens/login_screen_pro.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DocYaApp());

  // 🔥 Inicializamos Firebase/FCM después de runApp
  _initFirebase();
}

Future<void> _initFirebase() async {
  try {
    await Firebase.initializeApp();

    // Pedir permisos de notificaciones
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint("🔔 Permisos notificaciones: ${settings.authorizationStatus}");

    // Token FCM
    final fcmToken = await FirebaseMessaging.instance.getToken();
    debugPrint("🔑 Token FCM: $fcmToken");
  } catch (e) {
    debugPrint("❌ Error inicializando Firebase: $e");
  }
}

class DocYaApp extends StatelessWidget {
  const DocYaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'DocYa',
      theme: ThemeData(
        primaryColor: const Color(0xFF14B8A6),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF14B8A6)),
      ),
      home: const LoginScreenPro(),
    );
  }
}
