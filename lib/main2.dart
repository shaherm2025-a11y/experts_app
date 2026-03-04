import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/admin_dashboard.dart';
import 'screens/expert_home_screen.dart';
import 'models/expert.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

runApp(const ExpertsApp());  
}

class ExpertsApp extends StatelessWidget {
  const ExpertsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
