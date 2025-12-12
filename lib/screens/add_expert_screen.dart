import 'package:flutter/material.dart';
import '../models/expert.dart';
import '../services/api_service.dart';
class AddExpertScreen extends StatefulWidget {
  const AddExpertScreen({super.key});

  @override
  State<AddExpertScreen> createState() => _AddExpertScreenState();
}

class _AddExpertScreenState extends State<AddExpertScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _jobController = TextEditingController();

  bool _canViewAll = false; // ✅ الحالة الجديدة

  void _saveExpert() async {
    if (_formKey.currentState!.validate()) {
      final expert = Expert(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        jobTitle: _jobController.text.trim(),
        canViewAll: _canViewAll ? 1 : 0, // ✅ إرسال القيمة
      );

      final success = await ApiService.addExpert(expert);
      if (success && mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('تمت الإضافة بنجاح')));
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إضافة خبير جديد')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'الاسم'),
                validator: (v) => v!.isEmpty ? 'الرجاء إدخال الاسم' : null,
              ),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'الإيميل'),
              ),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'كلمة المرور'),
              ),
              TextFormField(
                controller: _jobController,
                decoration: const InputDecoration(labelText: 'المسمى الوظيفي'),
              ),

              const SizedBox(height: 12),

              // ✅ مربع التحديد الجديد
              CheckboxListTile(
                value: _canViewAll,
                onChanged: (v) => setState(() => _canViewAll = v ?? false),
                title: const Text('يمكنه رؤية كل ردود الخبراء'),
              ),

              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saveExpert,
                child: const Text('حفظ'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
