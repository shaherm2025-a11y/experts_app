import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'expert_home_screen.dart';


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;

  void _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final res = await ApiService.loginExpert(
      _nameController.text.trim(),
      _passwordController.text.trim(),
    );

    setState(() => _loading = false);
if (res['status'] == 'success') {
  final expertId = res['expert_id'];

  if (res['is_admin'] == true) {
    Navigator.pushReplacementNamed(context, '/admin');
  } else {
    //Navigator.pushReplacement(
     // context,
     // MaterialPageRoute(
     //   builder: (_) => ExpertHomeScreen(expertId: expertId),
     // ),
   // );
   
    Navigator.pushReplacementNamed(
    context,
   '/expert',
    arguments: expertId,
   );
  }
}

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تسجيل دخول الخبير')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'الاسم'),
            ),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'كلمة المرور'),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ElevatedButton(
              onPressed: _loading ? null : _login,
              child: _loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('دخول'),
            ),
          ],
        ),
      ),
    );
  }
}
