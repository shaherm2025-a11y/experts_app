import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/admin_dashboard.dart';
import 'screens/expert_home_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

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
  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings =
  InitializationSettings(android: initializationSettingsAndroid);

  await flutterLocalNotificationsPlugin.initialize(
  initializationSettings,
  onDidReceiveNotificationResponse: (NotificationResponse response) {
    navigatorKey.currentState?.pushNamed('/login');
  },
);
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'high_importance_channel',
  'High Importance Notifications',
  importance: Importance.high,
  );

   await flutterLocalNotificationsPlugin
    .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
    ?.createNotificationChannel(channel);

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

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {

  if (message.notification != null) {

    flutterLocalNotificationsPlugin.show(
      0,
      message.notification!.title,
      message.notification!.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'high_importance_channel',
          'High Importance Notifications',
          importance: Importance.max,
          priority: Priority.high,
        ),
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

  void _handleNotificationNavigation(RemoteMessage message) async {

  final data = message.data;

  if (data['type'] == 'new_question') {

    final prefs = await SharedPreferences.getInstance();
    final expertId = prefs.getInt('expert_id');

    if (expertId != null) {
      navigatorKey.currentState?.pushNamed('/expert', arguments: expertId);
    } else {
      navigatorKey.currentState?.pushNamed('/login');
    }
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