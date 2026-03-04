import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/admin_dashboard.dart';
import 'screens/expert_home_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

final GlobalKey<NavigatorState> navigatorKey =
    GlobalKey<NavigatorState>();

// ================== Background Handler ==================
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

// ================== MAIN ==================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  FirebaseMessaging.onBackgroundMessage(
      _firebaseBackgroundHandler);

  runApp(const ExpertsApp());
}

// ================== APP ==================
class ExpertsApp extends StatefulWidget {
  const ExpertsApp({super.key});

  @override
  State<ExpertsApp> createState() => _ExpertsAppState();
}

class _ExpertsAppState extends State<ExpertsApp> {

  @override
  void initState() {
    super.initState();
    _initFCM();
  }

  void _initFCM() async {

    // طلب الإذن (مهم لأندرويد 13+)
    await FirebaseMessaging.instance.requestPermission();

    // ================= FOREGROUND =================
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        ScaffoldMessenger.of(
                navigatorKey.currentContext!)
            .showSnackBar(
          SnackBar(
            content: Text(
                message.notification!.title ?? "إشعار جديد"),
          ),
        );
      }
    });

    // ================= عند الضغط على الإشعار =================
    FirebaseMessaging.onMessageOpenedApp
        .listen((RemoteMessage message) {
      _handleNotificationNavigation(message);
    });

    // ================= إذا كان التطبيق مغلق =================
    RemoteMessage? initialMessage =
        await FirebaseMessaging.instance
            .getInitialMessage();

    if (initialMessage != null) {
      _handleNotificationNavigation(initialMessage);
    }
  }

  void _handleNotificationNavigation(RemoteMessage message) {

    final data = message.data;

    if (data['type'] == 'new_question') {

      final expertId =
          int.tryParse(data['expert_id'] ?? "0") ?? 0;

      navigatorKey.currentState?.pushNamed(
        '/expert',
        arguments: expertId,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'تطبيق الخبراء',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.green),
      home: const LoginScreen(),
      routes: {
        '/admin': (context) => const AdminDashboard(),
        '/expert': (context) {
          final expertId =
              ModalRoute.of(context)!.settings.arguments as int;

          return ExpertHomeScreen(expertId: expertId);
        },
      },
    );
  }
}