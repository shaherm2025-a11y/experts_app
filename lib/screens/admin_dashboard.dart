import 'package:flutter/material.dart';
import '../models/expert.dart';
import '../services/api_service.dart';
import 'add_expert_screen.dart';
import 'expert_home_screen.dart'; // ✅ لفتح واجهة الخبراء
import '../widgets/expert_card.dart';
import 'edit_profile_screen.dart';
import 'answered_report_screen.dart';
import 'answered_details_report_screen.dart';


class AdminDashboard extends StatefulWidget {
  final int adminExpertId;

  const AdminDashboard({
    super.key,
    required this.adminExpertId,
  });

  @override
  State<AdminDashboard> createState() =>
      _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  List<Expert> experts = [];
  
 void _openAnsweredReport() {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => AnsweredReportScreen(
        adminExpertId: widget.adminExpertId,
      ),
    ),
  );
}

void _openAnsweredDetailsReport() {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => AnsweredDetailsReportScreen(
        adminExpertId: widget.adminExpertId,
      ),
    ),
  );
}
  void _loadExperts() async {
    final data = await ApiService.getExperts();
    setState(() => experts = data);
  }

  @override
  void initState() {
    super.initState();
    _loadExperts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('لوحة تحكم المدير', style: TextStyle(fontSize: 20)),
        backgroundColor: Colors.green[700],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 🔹 أزرار الإدارة في الأعلى
          
Row(
  children: [
    Expanded(
      child: ElevatedButton.icon(
        icon: const Icon(Icons.manage_accounts),
        label: const Text('إدارة المستخدمين'),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ManageExpertsPage(),
            ),
          );
        },
      ),
    ),
    const SizedBox(width: 8),
    Expanded(
      child: ElevatedButton.icon(
        icon: const Icon(Icons.chat),
        label: const Text('واجهة الخبراء'),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ExpertHomeScreen(
                expertId: 1,
              ),
            ),
          );
        },
      ),
    ),
    const SizedBox(width: 8),
    Expanded(
      child: ElevatedButton.icon(
        icon: const Icon(Icons.bar_chart),
        label: const Text('تقرير الإجابات'),
        onPressed: _openAnsweredReport,
      ),
    ),
  ],
 ),
            const SizedBox(height: 8),

            SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
            icon: const Icon(Icons.description),
            label: const Text('التقرير التفصيلي'),
            style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal.shade700,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 13),
            ),
            onPressed: _openAnsweredDetailsReport,
            ),
            ),
            const SizedBox(height: 20),
            const Divider(),

            // 🔹 قائمة الخبراء
            const Align(
              alignment: Alignment.centerRight,
              child: Text(
                'قائمة الخبراء المسجلين:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            const SizedBox(height: 10),

            Expanded(
              child: ListView.builder(
                itemCount: experts.length,
                itemBuilder: (context, index) {
                  final expert = experts[index];
                  return ExpertCard(
                    expert: expert,
                    onDelete: () async {
                      await ApiService.deleteExpert(expert.id!);
                      _loadExperts();
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ✅ صفحة فرعية لإدارة المستخدمين
class ManageExpertsPage extends StatefulWidget {
  const ManageExpertsPage({super.key});

  @override
  State<ManageExpertsPage> createState() => _ManageExpertsPageState();
}

class _ManageExpertsPageState extends State<ManageExpertsPage> {
  List<Expert> experts = [];

  void _loadExperts() async {
    final data = await ApiService.getExperts();
    setState(() => experts = data);
  }

  @override
  void initState() {
    super.initState();
    _loadExperts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة المستخدمين'),
        backgroundColor: Colors.blue[700],
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddExpertScreen()),
              );
              _loadExperts();
            },
          ),
        ],
      ),
      body: ListView.builder(
  itemCount: experts.length,
  itemBuilder: (context, index) {
    final expert = experts[index];
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: ListTile(
        title: Text(expert.name),
        subtitle: Text(expert.email),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ✅ زر التعديل
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              tooltip: 'تعديل بيانات الخبير',
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EditProfileScreen(
                      expertId: expert.id!,
                      isAdmin: true, // المدير فقط
                    ),
                  ),
                );
                _loadExperts(); // لإعادة تحميل القائمة بعد التعديل
              },
            ),
            // ❌ زر الحذف (موجود مسبقًا)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () async {
                await ApiService.deleteExpert(expert.id!);
                _loadExperts();
              },
            ),
          ],
        ),
      ),
    );
   },
),

    );
  }
}
	