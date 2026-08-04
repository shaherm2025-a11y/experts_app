
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'expert_home_screen.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {

  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();

  // 🔐 التخزين الآمن لاسم المستخدم وكلمة المرور
  final FlutterSecureStorage _secureStorage =
      const FlutterSecureStorage();

  bool _loading = false;

  // ☑️ حفظ بيانات الدخول
  bool _rememberLogin = false;

  String? _error;

  @override
  void initState() {
    super.initState();

    _loadSavedLogin();
  }

  // =========================================================
  // 🔐 تحميل بيانات الدخول المحفوظة
  // =========================================================

  Future<void> _loadSavedLogin() async {

    try {

      final savedName =
          await _secureStorage.read(
        key: 'saved_expert_name',
      );

      final savedPassword =
          await _secureStorage.read(
        key: 'saved_expert_password',
      );

      if (!mounted) return;

      setState(() {

        if (savedName != null &&
            savedName.isNotEmpty) {

          _nameController.text =
              savedName;
        }

        if (savedPassword != null &&
            savedPassword.isNotEmpty) {

          _passwordController.text =
              savedPassword;
        }

        _rememberLogin =
            savedName != null &&
            savedPassword != null &&
            savedName.isNotEmpty &&
            savedPassword.isNotEmpty;
      });

    } catch (e) {

      debugPrint(
        "Error loading saved login: $e",
      );

    }
  }

  // =========================================================
  // 🔐 حفظ أو حذف بيانات الدخول
  // =========================================================

  Future<void> _saveLoginData() async {

    try {

      if (_rememberLogin) {

        await _secureStorage.write(
          key: 'saved_expert_name',
          value: _nameController.text.trim(),
        );

        await _secureStorage.write(
          key: 'saved_expert_password',
          value: _passwordController.text.trim(),
        );

        debugPrint(
          "Login information saved securely",
        );

      } else {

        await _secureStorage.delete(
          key: 'saved_expert_name',
        );

        await _secureStorage.delete(
          key: 'saved_expert_password',
        );

        debugPrint(
          "Saved login information deleted",
        );
      }

    } catch (e) {

      debugPrint(
        "Error saving login information: $e",
      );

    }
  }

  // =========================================================
  // تسجيل الدخول
  // =========================================================

  Future<void> _login() async {

    final name =
        _nameController.text.trim();

    final password =
        _passwordController.text.trim();

    // التحقق من الحقول
    if (name.isEmpty ||
        password.isEmpty) {

      setState(() {

        _error =
            'يرجى إدخال اسم المستخدم وكلمة المرور';

      });

      return;
    }

    setState(() {

      _loading = true;
      _error = null;

    });

    try {

      // =====================================================
      // الاتصال بالسيرفر
      // =====================================================

      final res =
          await ApiService.loginExpert(
        name,
        password,
      );

      if (!mounted) return;

      // =====================================================
      // نجاح تسجيل الدخول
      // =====================================================

      if (res['status'] == 'success') {

        final expertId =
            res['expert_id'];

        // ===================================================
        // SharedPreferences:
        // نحفظ فقط رقم الخبير
        // ===================================================

        final prefs =
            await SharedPreferences.getInstance();

        await prefs.setInt(
          'expert_id',
          expertId,
        );

        // ===================================================
        // 🔐 حفظ اسم المستخدم وكلمة المرور بشكل آمن
        // ===================================================

        await _saveLoginData();

        // ===================================================
        // 🔔 طلب إذن الإشعارات
        // ===================================================

        await FirebaseMessaging.instance
            .requestPermission();

        // ===================================================
        // 🔔 الحصول على FCM Token
        // ===================================================

        final token =
            await FirebaseMessaging.instance
                .getToken();

        debugPrint(
          "FCM TOKEN: $token",
        );

        // ===================================================
        // 🔔 إرسال FCM Token للسيرفر
        // ===================================================

        if (token != null) {

          await ApiService.saveFcmToken(
            userId: expertId,
            role: "expert",
            token: token,
          );

        }

        if (!mounted) return;

        // ===================================================
        // الانتقال حسب نوع المستخدم
        // ===================================================

        if (res['is_admin'] == true) {

          Navigator.pushReplacementNamed(
            context,
            '/admin',
          );

        } else {

          Navigator.pushReplacementNamed(
            context,
            '/expert',
            arguments: expertId,
          );

        }

      } else {

        // ===================================================
        // فشل تسجيل الدخول
        // ===================================================

        setState(() {

          _loading = false;

          _error =
              res['message'] ??
              'اسم المستخدم أو كلمة المرور غير صحيحة';

        });

      }

    } catch (e) {

      if (!mounted) return;

      setState(() {

        _loading = false;

        _error =
            'حدث خطأ أثناء تسجيل الدخول';

      });

      debugPrint(
        "Login error: $e",
      );
    }
  }

  @override
  void dispose() {

    _nameController.dispose();

    _passwordController.dispose();

    super.dispose();
  }

  // =========================================================
  // واجهة تسجيل الدخول
  // =========================================================

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: const Text(
          'تسجيل دخول الخبير',
        ),
      ),

      body: Padding(

        padding:
            const EdgeInsets.all(16.0),

        child: Column(

          children: [

            // =================================================
            // اسم المستخدم
            // =================================================

            TextField(

              controller:
                  _nameController,

              decoration:
                  const InputDecoration(

                labelText: 'الاسم',

                prefixIcon:
                    Icon(Icons.person),

              ),
            ),

            const SizedBox(
              height: 12,
            ),

            // =================================================
            // كلمة المرور
            // =================================================

            TextField(

              controller:
                  _passwordController,

              obscureText: true,

              decoration:
                  const InputDecoration(

                labelText:
                    'كلمة المرور',

                prefixIcon:
                    Icon(Icons.lock),

              ),
            ),

            const SizedBox(
              height: 8,
            ),

            // =================================================
            // ☑️ حفظ بيانات الدخول
            // =================================================

            Align(

              alignment:
                  Alignment.centerRight,

              child:
                  CheckboxListTile(

                contentPadding:
                    EdgeInsets.zero,

                title:
                    const Text(
                  'حفظ اسم المستخدم وكلمة المرور',
                ),

                value:
                    _rememberLogin,

                controlAffinity:
                    ListTileControlAffinity.leading,

                onChanged:
                    (value) {

                  setState(() {

                    _rememberLogin =
                        value ?? false;

                  });

                },
              ),
            ),

            const SizedBox(
              height: 12,
            ),

            // =================================================
            // رسالة الخطأ
            // =================================================

            if (_error != null)

              Padding(

                padding:
                    const EdgeInsets.only(
                  bottom: 12,
                ),

                child: Text(

                  _error!,

                  style:
                      const TextStyle(
                    color: Colors.red,
                  ),

                  textAlign:
                      TextAlign.center,
                ),
              ),

            // =================================================
            // زر الدخول
            // =================================================

            SizedBox(

              width:
                  double.infinity,

              child:
                  ElevatedButton(

                onPressed:
                    _loading
                        ? null
                        : _login,

                child:
                    _loading

                        ? const SizedBox(

                            width: 22,
                            height: 22,

                            child:
                                CircularProgressIndicator(
                              color:
                                  Colors.white,
                              strokeWidth:
                                  2,
                            ),
                          )

                        : const Text(
                            'دخول',
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
