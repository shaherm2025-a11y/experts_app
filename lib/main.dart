import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/admin_dashboard.dart';
import 'screens/expert_home_screen.dart';
import 'models/expert.dart';

void main() {
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
       // '/expert': (context) => const ExpertHomeScreen(),
      },
    );
  }
}
