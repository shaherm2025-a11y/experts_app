import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ExpertHomeScreen extends StatefulWidget {
  final int expertId;

  const ExpertHomeScreen({super.key, this.expertId = 1}); // ← يمكنك تمرير id الخبير بعد تسجيل الدخول

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
        title: Text('إجابة على السؤال رقم ${question['id']}'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(hintText: 'اكتب إجابتك هنا...'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              final success = await ApiService.answerQuestion(
                questionId: question['id'],
                expertId: widget.expertId,
                answer: controller.text.trim(),
              );
              if (success && mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✅ تم إرسال الإجابة بنجاح')),
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
        appBar: AppBar(
          title: const Text('الأسئلة الموجهة إليك'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'غير مجابة'),
              Tab(text: 'تمت الإجابة'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // الأسئلة غير المجابة
            ListView.builder(
              itemCount: unanswered.length,
              itemBuilder: (context, index) {
                final q = unanswered[index];
                return Card(
                  margin: const EdgeInsets.all(8),
                  child: ListTile(
                    title: Text(q['question']),
                    leading: q['image'] != null
                        ? Image.memory(
                            Uri.parse('data:image/jpeg;base64,${q['image']}').data!.contentAsBytes(),
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                          )
                        : const Icon(Icons.image_not_supported),
                    trailing: IconButton(
                      icon: const Icon(Icons.reply, color: Colors.green),
                      onPressed: () => _showAnswerDialog(q),
                    ),
                  ),
                );
              },
            ),

            // الأسئلة المجابة
            ListView.builder(
              itemCount: answered.length,
              itemBuilder: (context, index) {
                final q = answered[index];
                return Card(
                  margin: const EdgeInsets.all(8),
                  child: ListTile(
                    title: Text(q['question']),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(),
                        Text('الإجابة: ${q['answer'] ?? "لا توجد"}'),
                      ],
                    ),
                    leading: q['image'] != null
                        ? Image.memory(
                            Uri.parse('data:image/jpeg;base64,${q['image']}').data!.contentAsBytes(),
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                          )
                        : const Icon(Icons.image_not_supported),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
