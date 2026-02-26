import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'edit_profile_screen.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'local_db.dart';


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
  
  final AudioPlayer player = AudioPlayer();
  final AudioRecorder record = AudioRecorder();
  List<Map<String, dynamic>> questions = [];
  Map<String, dynamic>? serverData;

 // @override
 // void initState() {
  //  super.initState();
   // _loadQuestions();
    // تحديث تلقائي
   // Timer.periodic(const Duration(seconds:300), (timer) {
   //   if (mounted) _loadQuestions();
   // });
 // }
  
  @override
  void initState() {
  super.initState();
  //_loadLocalQuestions();  // تحميل محلي
  _loadQuestions();
  _syncWithServer();      // تحديث من السيرفر
  }  
  
  @override
  void dispose() {
    player.dispose();   // 👈 هنا
	record.dispose();
    super.dispose();
  }
  
  Future<void> _loadLocalQuestions() async {
  final localData = await LocalDB.getAllQuestions();
  setState(() {
    questions = localData;
  });
}

Future<void> _syncWithServer() async {
  try {
   final data = await ApiService.getExpertDiagnoses(widget.expertId);

    for (var q in serverData) {
      await LocalDB.insertOrUpdateQuestion(q);
    }

   // await _loadLocalQuestions(); // تحديث الواجهة
      await _loadQuestions();

  } catch (e) {
    print("فشل المزامنة: $e");
  }
}

  Future<String> _downloadAndSaveFile(String url, String fileName) async {
  final response = await http.get(Uri.parse(url));

  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/$fileName');

  await file.writeAsBytes(response.bodyBytes);

  return file.path;
}

  Future<void> _loadQuestions() async {
  setState(() => loading = true);

  try {
    final data = await ApiService.getExpertDiagnoses(widget.expertId);

    unanswered = List<Map<String, dynamic>>.from(data['unanswered']);
    answered = List<Map<String, dynamic>>.from(data['answered']);

    // 🔥 حفظ الأسئلة محلياً
    for (var q in [...unanswered, ...answered]) {

      await LocalDB.insertQuestion({
        "id": q["id"],
        "question": q["question"],
        "answer": q["answer"],
        "status": q["status"],
        "question_date": q["question_date"],
      });

      // تحميل الصورة
      final imagePath = await _downloadAndSaveFile(
        "${ApiService.baseUrl}/expert_question_image/${q['id']}",
        "q_${q['id']}.jpg",
      );

      await LocalDB.updateQuestionImagePath(q['id'], imagePath);

      // تحميل صوت السؤال
      try {
        final audioPath = await _downloadAndSaveFile(
          "${ApiService.baseUrl}/expert_question_audio/${q['id']}",
          "q_${q['id']}.mp3",
        );

        await LocalDB.updateQuestionAudioPath(q['id'], audioPath);
      } catch (_) {}

      // تحميل صوت الرد إذا موجود
      if (q["status"] == 1) {
        try {
          final answerAudioPath = await _downloadAndSaveFile(
            "${ApiService.baseUrl}/expert_answer_audio/${q['id']}",
            "a_${q['id']}.mp3",
          );

          await LocalDB.updateAnswer(
              q['id'], q['answer'] ?? "", answerAudioPath);
        } catch (_) {}
      }
    }

    setState(() => loading = false);

  } catch (e) {

    // 🔥 في حالة عدم وجود إنترنت → جلب من SQLite
    final localUnanswered = await LocalDB.getUnanswered();
    final localAnswered = await LocalDB.getAnswered();

    setState(() {
      unanswered = localUnanswered;
      answered = localAnswered;
      loading = false;
    });
  }
}

Future<void> _showAnswerDialog(Map<String, dynamic> q) async {
  TextEditingController answerController =
      TextEditingController(text: q['answer'] ?? '');
  bool isRecording = false;

  showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(builder: (context, setState) {
        return AlertDialog(
          title: const Text('الرد على الاستفسار'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: answerController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'اكتب ردك هنا...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  IconButton(
                    icon: Icon(isRecording ? Icons.stop : Icons.mic),
                    color: isRecording ? Colors.red : Colors.blue,
                    onPressed: () async {
                    try {

                     if (!isRecording) {

                      // طلب الإذن
                     bool hasPermission = await record.hasPermission();
                    if (!hasPermission) {
                      ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('يرجى السماح باستخدام الميكروفون')),
                      );
                      return;
                     }

                    // بدء التسجيل
                    await record.start(
                     const RecordConfig(
                     encoder: AudioEncoder.aacLc,
                     bitRate: 128000,
                     sampleRate: 44100,
                      ),
                     path: 'answer_${q['id']}.m4a',
                    );

                   setState(() => isRecording = true);

                   } else {

                   // إيقاف التسجيل
                     String? path = await record.stop();

                     setState(() => isRecording = false);

                     if (path != null) {

                    // حفظ المسار في الخريطة
                      q['answer_audio_path'] = path;

                      ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم تسجيل الصوت بنجاح')),
                       );

                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('فشل في حفظ التسجيل')),
                      );
                     }
                    }

                   } catch (e) {
                    print("Recording error: $e");
                    ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('حدث خطأ أثناء التسجيل')),
                     );
                   }
                  },
                  ),
                  const SizedBox(width: 8),
                  if (q['answer_audio_path'] != null)
                    IconButton(
                      icon: const Icon(Icons.play_arrow),
                      onPressed: () async {
                        try {
                          await player.stop();
                          await player.play(DeviceFileSource(q['answer_audio_path']));
                        } catch (e) {
                          print("خطأ في تشغيل صوت الرد: $e");
                        }
                      },
                    ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('إلغاء'),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              child: const Text('إرسال'),
              onPressed: () async {
                try {
                  // ارسال النص + مسار الصوت إن وجد
                  final success = await ApiService.answerQuestion(
                    q['id'],
                    answerController.text,
                    audioFile: q['answer_audio_path'] != null
                        ? File(q['answer_audio_path'])
                        : null,
                  );

                  if (success) {
				    await LocalDB.updateAnswer(
                    q['id'],
                    answerController.text.trim(),
                    q['answer_audio_path'],
                    );
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم إرسال الرد')),
                    );
                    _loadQuestions(); // إعادة تحميل الأسئلة بعد الرد
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('فشل إرسال الرد')),
                    );
                  }
                } catch (e) {
                  print("خطأ في إرسال الرد: $e");
                }
              },
            ),
          ],
        );
      });
    },
  );
}
 void _showFullImage(String? imagePath) {
  showDialog(
    context: context,
    builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      child: InteractiveViewer(
        panEnabled: true,
        minScale: 0.5,
        maxScale: 5.0,
        child: imagePath != null && File(imagePath).existsSync()
            ? Image.file(
                File(imagePath),
                fit: BoxFit.contain,
              )
            : const Center(
                child: Icon(Icons.image_not_supported, size: 80, color: Colors.white),
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
                  // زر تشغيل صوت الاستفسار
                  if (q['question_audio_path'] != null &&
                      File(q['question_audio_path']).existsSync())
                    IconButton(
                      icon: const Icon(Icons.volume_up),
                      onPressed: () async {
                        try {
                          await player.stop(); // توقف أي تشغيل سابق
                          await player.play(
                              DeviceFileSource(q['question_audio_path']));
                        } catch (e) {
                          print("خطأ في تشغيل صوت الاستفسار: $e");
                        }
                      },
                    ),
                  // زر تشغيل صوت الرد
                  if (q['answer_audio_path'] != null &&
                      File(q['answer_audio_path']).existsSync())
                    IconButton(
                      icon: const Icon(Icons.play_arrow),
                      onPressed: () async {
                        try {
                          await player.stop(); // توقف أي تشغيل سابق
                          await player.play(
                              DeviceFileSource(q['answer_audio_path']));
                        } catch (e) {
                          print("خطأ في تشغيل صوت الرد: $e");
                        }
                      },
                    ),
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
        onTap: () => _showFullImage(q['image_path']),
        child: Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            image: q['image_path'] != null && File(q['image_path']).existsSync()
                ? DecorationImage(
                    image: FileImage(File(q['image_path'])),
                    fit: BoxFit.cover,
                  )
                : const DecorationImage(
                    image: AssetImage("assets/placeholder.png"),
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
