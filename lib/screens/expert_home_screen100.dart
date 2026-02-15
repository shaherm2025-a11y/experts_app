import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'edit_profile_screen.dart';


class ExpertHomeScreen extends StatefulWidget {
  final int expertId;

  const ExpertHomeScreen({super.key, this.expertId = 1});

  @override
  State<ExpertHomeScreen> createState() => _ExpertHomeScreenState();
}

class _ExpertHomeScreenState extends State<ExpertHomeScreen> {
  List<Map<String, dynamic>> unanswered = [];
  List<Map<String, dynamic>> answered = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
    // تحديث تلقائي
    Timer.periodic(const Duration(seconds:300), (timer) {
      if (mounted) _loadQuestions();
    });
  }

  Future<void> _loadQuestions() async {
    setState(() => loading = true);
    try {
      final data = await ApiService.getExpertDiagnoses(widget.expertId);
      setState(() {
        unanswered = List<Map<String, dynamic>>.from(data['unanswered']);
        answered = List<Map<String, dynamic>>.from(data['answered']);
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
    }
  }

  void _showAnswerDialog(Map<String, dynamic> question) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('الرد على الاستفسار المحدد'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'اكتب ردك هنا...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              final success = await ApiService.answerQuestion(
                questionId: question['id'],
                expertId: widget.expertId,
                answer: controller.text.trim(),
              );
              if (success && mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✅ تم ارسال الرد بنجاح')),
                );
                _loadQuestions();
              }
            },
            child: const Text('إرسال'),
          ),
        ],
      ),
    );
  }

 void _showFullImage(int questionId) {
  showDialog(
    context: context,
    builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      child: InteractiveViewer(
        panEnabled: true,
        minScale: 0.5,
        maxScale: 5.0,
        child: Image.network(
          "${ApiService.baseUrl}/expert_question_image/$questionId",
          fit: BoxFit.contain,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return const Center(child: CircularProgressIndicator());
          },
        ),
      ),
    ),
  );
}

  Widget _buildQuestionCard(Map<String, dynamic> q, {bool answeredCard = false}) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        title: Text(
          q['question'],
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: answeredCard
            ? Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(),
                    Text(
                      'الإجابة (${q['expert_name'] ?? 'مجهول'}): ${q['answer'] ?? "لا توجد"}',
                      style: const TextStyle(fontSize: 14, color: Colors.black87),
                    ),
					const SizedBox(height: 4),
                    Text(
                      '📅 تاريخ الرد: ${q['diagnosis_date'] ?? "غير متاح"}',
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                       ),
					const SizedBox(height: 4),
                    Text(
                      '📅 تاريخ الاستفسار: ${q['question_date'] ?? "غير متاح"}',
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                       ),   
                  ],
                ),
              )
            : null,
        leading: GestureDetector(
         onTap: () => _showFullImage(q['id']),
         child: Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          image: DecorationImage(
           image: NetworkImage(
            "${ApiService.baseUrl}/expert_question_image/${q['id']}",
           ),
           fit: BoxFit.cover,
           ),
          ),
         ),
        ),

        trailing: !answeredCard
            ? IconButton(
                icon: const Icon(Icons.reply, color: Colors.green, size: 28),
                onPressed: () => _showAnswerDialog(q),
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
  backgroundColor: Colors.green[700],
  title: const Text(
    'الاستفسارات من المزارعين',
    style: TextStyle(fontSize: 20),
  ),
  actions: [
    IconButton(
      icon: const Icon(Icons.settings),
      tooltip: 'تعديل معلومات الحساب',
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EditProfileScreen(
              expertId: widget.expertId,
              isAdmin: false, // الخبير العادي
            ),
          ),
        );
      },
    ),
  ],
  bottom: const TabBar(
    indicatorColor: Colors.white,
    indicatorWeight: 4,
    tabs: [
      Tab(text: 'لم يتم الرد عليها'),
      Tab(text: 'تم الرد عليها'),
    ],
  ),
),

        body: TabBarView(
          children: [
            // الأسئلة غير المجابة
            RefreshIndicator(
              onRefresh: _loadQuestions,
              child: ListView.builder(
                padding: const EdgeInsets.only(top: 8),
                itemCount: unanswered.length,
                itemBuilder: (context, index) {
                  return _buildQuestionCard(unanswered[index]);
                },
              ),
            ),

            // الأسئلة المجابة
            RefreshIndicator(
              onRefresh: _loadQuestions,
              child: ListView.builder(
                padding: const EdgeInsets.only(top: 8),
                itemCount: answered.length,
                itemBuilder: (context, index) {
                  return _buildQuestionCard(answered[index], answeredCard: true);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
