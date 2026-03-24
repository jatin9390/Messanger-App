import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'widgets/offline_banner.dart';

import 'services/notification_service.dart';
import 'package:telephony/telephony.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("Handling a background message: ${message.messageId}");
}

@pragma('vm:entry-point')
void backgrounMessageHandler(SmsMessage message) async {
  await NotificationService.showNotification(
    id: message.id ?? 0,
    title: message.address ?? "New SMS",
    body: message.body ?? "",
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await NotificationService.init();

  Telephony.instance.listenIncomingSms(
    onNewMessage: (SmsMessage message) {
      NotificationService.showNotification(
        id: message.id ?? 1,
        title: message.address ?? "New SMS",
        body: message.body ?? "",
      );
    },
    onBackgroundMessage: backgrounMessageHandler,
  );

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    debugPrint('Got a message whilst in the foreground!');
    if (message.notification != null) {
      debugPrint('Message also contained a notification: ${message.notification!.title}');
    }
  });

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    debugPrint('Notification tapped!');
  });
  
  runApp(const MyApp());
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, // Added key for background navigation
      debugShowCheckedModeBanner: false,
      title: 'Real-Time App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6A11CB)),
        useMaterial3: true,
      ),
      builder: (context, child) {
        // Automatically injects the Offline Banner above every single screen!
        return Scaffold(
          body: OfflineBanner(child: child!),
        );
      },
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // StreamBuilder listens to authentication state changes entirely automatically!
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        
        // If the user object is present, they are securely logged in
        if (snapshot.hasData) {
          // Securely sync their device's Push Notification Token to the database
          FirebaseMessaging.instance.getToken().then((token) {
            if (token != null) {
              debugPrint("DEBUG: Your FCM Token is: $token");
              FirebaseFirestore.instance
                  .collection('users')
                  .doc(snapshot.data!.uid)
                  .set({'fcmToken': token}, SetOptions(merge: true))
                  .catchError((e) {
                debugPrint("DEBUG: Error saving token: $e");
              });
            }
          });

          return const HomeScreen();
        }
        
        // Otherwise, show the login screen
        return const LoginScreen();
      },
    );
  }
}
