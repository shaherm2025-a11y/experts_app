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

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class ExpertHomeScreen extends StatefulWidget {
  final int expertId;

  const ExpertHomeScreen({Key? key, required this.expertId})
      : super(key: key);

  @override
  State<ExpertHomeScreen> createState() => _ExpertHomeScreenState();
}

class _ExpertHomeScreenState extends State<ExpertHomeScreen> {
  List<Map<String, dynamic>> unanswered = [];
  List<Map<String, dynamic>> answered = [];
  bool loading = true;

  final AudioPlayer player = AudioPlayer();
  final AudioRecorder record = AudioRecorder();
  Timer? _timer;
  

  @override
  void initState() {
    super.initState();
    _loadQuestions();
    syncUnsyncedAnswers();
	//await FirebaseMessaging.instance.requestPermission();
	 initFirebase();

    _timer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (!mounted) return;
      _loadQuestions();
      syncUnsyncedAnswers();
    });
  }
  
  Future<void> initFirebase() async {
  await FirebaseMessaging.instance.requestPermission();
 }

  @override
  void dispose() {
    _timer?.cancel();
    player.dispose();
    record.dispose();
    super.dispose();
  }
	  
Future<String?> _downloadAndSaveFile(String url, String fileName) async {
  try {
    final response = await http.get(Uri.parse(url));

    // إذا لم يكن الملف موجود في السيرفر (مثل 404)
    if (response.statusCode != 200) {
      debugPrint("File not found on server: $url");
      return null;
    }

    // تأكد أن الملف ليس فارغ
    if (response.bodyBytes.isEmpty) {
      debugPrint("Empty file from server: $url");
      return null;
    }

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName');

    await file.writeAsBytes(response.bodyBytes);

    debugPrint("Saved file: ${file.path} size=${response.bodyBytes.length}");

    return file.path;

  } catch (e) {
    debugPrint("Download error: $url  error=$e");
    return null;
  }
}
	Future<void> syncUnsyncedAnswers() async {
  final unsynced = await LocalDB.getUnsyncedAnswers();

  for (var q in unsynced) {
    final success = await ApiService.answerQuestion(
      q['id'],
      q['answer'] ?? "",
      q['expert_id'],   // ✅ رقم الخبير الصحيح لكل رد
      audioFile: q['answer_audio_path'] != null
          ? File(q['answer_audio_path'])
          : null,
    );

    if (success) {
      await LocalDB.updateAnswer(
        q['id'],
        q['answer'],
        q['answer_audio_path'],
        q['expert_id'],   // لا تغيّره
        isSynced: 1,
      );
    }
  }
}

	Future<void> _loadQuestions() async {
	  setState(() => loading = true);

	  // 1️⃣ أولاً: تحميل من SQLite فوراً
	  final localUnanswered = await LocalDB.getUnanswered();
	  final localAnswered = await LocalDB.getAnswered();

	  setState(() {
		unanswered = localUnanswered;
		answered = localAnswered;
	  });

	  try {
		// 2️⃣ ثانياً: جلب من السيرفر
		final data =
			await ApiService.getExpertDiagnoses(widget.expertId);

		List<Map<String, dynamic>> serverUnanswered =
			List<Map<String, dynamic>>.from(data['unanswered']);

		List<Map<String, dynamic>> serverAnswered =
			List<Map<String, dynamic>>.from(data['answered']);

		// 3️⃣ حفظ في SQLite + تحميل الملفات
		for (var q in [...serverUnanswered, ...serverAnswered]) {

		  await LocalDB.insertOrUpdateQuestion({
          "id": q["id"],
          "question": q["question"],
          "answer": q["answer"],
          "expert_name": q["expert_name"],
          "status": q["status"],
          "question_date": q["question_date"],
          "diagnosis_date": q["diagnosis_date"],
          });

		  // تحميل الصورة
       try {

        final dir = await getApplicationDocumentsDirectory();
        final filePath = '${dir.path}/q_${q['id']}.jpg';
        final file = File(filePath);

        // 📥 حمّل فقط إذا غير موجودة محلياً
        if (!file.existsSync()) {

          final imagePath = await _downloadAndSaveFile(
          "${ApiService.baseUrl}/expert_question_image/${q['id']}",
          "q_${q['id']}.jpg",
        );

        // 📌 حدث قاعدة البيانات فقط إذا تم التحميل فعلاً
        if (imagePath != null && imagePath.isNotEmpty) {
         await LocalDB.updateQuestionImagePath(q['id'], imagePath);
        }

      }

      } catch (e) {
      // تجاهل الخطأ إذا لم تكن هناك صورة
      debugPrint("No image for question ${q['id']}");
       }
// تحميل صوت السؤال
try {

  final dir = await getApplicationDocumentsDirectory();
  final filePath = '${dir.path}/q_${q['id']}.mp3';
  final file = File(filePath);

  // حمّل فقط إذا غير موجود محلياً
  if (!file.existsSync()) {

    final audioPath = await _downloadAndSaveFile(
      "${ApiService.baseUrl}/expert_question_audio/${q['id']}",
      "q_${q['id']}.mp3",
    );

    // حدث قاعدة البيانات فقط إذا تم التحميل فعلاً
    if (audioPath != null && audioPath.isNotEmpty) {
      await LocalDB.updateQuestionAudioPath(q['id'], audioPath);
    }

  }

} catch (e) {
  debugPrint("No question audio for id ${q['id']}");
}

		 // تحميل صوت الرد إن وجد
if (q["status"] == 1) {
  try {

    final dir = await getApplicationDocumentsDirectory();
    final filePath = '${dir.path}/a_${q['id']}.mp3';
    final file = File(filePath);

    // حمّل فقط إذا غير موجود محلياً
    if (!file.existsSync()) {

      final answerAudioPath = await _downloadAndSaveFile(
        "${ApiService.baseUrl}/expert_answer_audio/${q['id']}",
        "a_${q['id']}.mp3",
      );

      // حدّث قاعدة البيانات فقط إذا تم التحميل فعلاً
      if (answerAudioPath != null && answerAudioPath.isNotEmpty) {
        await LocalDB.updateAnswerAudioPath(
          q['id'],
          answerAudioPath,
        );
      }

    }

  } catch (e) {
    debugPrint("No answer audio for id ${q['id']}");
  }
}
		}

		// 4️⃣ إعادة قراءة SQLite بعد التحديث
		final updatedUnanswered = await LocalDB.getUnanswered();
		final updatedAnswered = await LocalDB.getAnswered();

		setState(() {
		  unanswered = updatedUnanswered;
		  answered = updatedAnswered;
		  loading = false;
		});

	  } catch (e) {
		// إذا فشل السيرفر — نعتمد على المحلي فقط
		setState(() => loading = false);
	  }
	}
	
Future<void> _showAnswerDialog(Map<String, dynamic> q) async {
    TextEditingController answerController =
        TextEditingController(text: q['answer'] ?? '');

    bool isRecording = false;
    bool isPlaying = false;
    File? audioAnswerFile;
    Duration duration = Duration.zero;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
 Future<void> startRecording() async {
   final hasPermission = await record.hasPermission();

  if (!hasPermission) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('يرجى السماح بالميكروفون')),
    );
    return;
  }

  final dir = await getTemporaryDirectory();

  final path =
      '${dir.path}/answer_${DateTime.now().millisecondsSinceEpoch}.m4a';

  try {
    await record.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: path,
    );

    setState(() => isRecording = true);

  } catch (e) {
    debugPrint("Start recording error: $e");
  }
}

 Future<void> stopRecording() async {
  try {
    final path = await record.stop();

    if (path == null || path.isEmpty) {
      setState(() => isRecording = false);
      return;
    }

    final dir = await getApplicationDocumentsDirectory();
    final savedPath =
        '${dir.path}/answer_${q['id']}_${DateTime.now().millisecondsSinceEpoch}.m4a';

    final savedFile = await File(path).copy(savedPath);

    setState(() {
      isRecording = false;
      audioAnswerFile = savedFile;   // 🔥 مهم جداً داخل setState
    });

  } catch (e) {
    setState(() => isRecording = false);
  }
}
         Future<void> playAudio() async {
           if (audioAnswerFile == null) return;

            try {
             await player.stop();
             await player.play(DeviceFileSource(audioAnswerFile!.path));
            } catch (e) {
            debugPrint("Play error: $e");
             }
            }
          void deleteAudio() {
           if (audioAnswerFile != null &&
            audioAnswerFile!.existsSync()) {
            audioAnswerFile!.deleteSync();
             }

           setState(() {
            audioAnswerFile = null;   // 🔥 داخل setState
           });
           }
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

                const SizedBox(height: 16),

                // 🎤 التسجيل
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                   ElevatedButton.icon(
                     icon: Icon(isRecording ? Icons.stop : Icons.mic),
                     label: Text(isRecording ? 'إيقاف' : 'تسجيل'),
                     style: ElevatedButton.styleFrom(
                     backgroundColor: isRecording ? Colors.red : Colors.green,
                    ),
                   onPressed: () async {
                   if (isRecording) {
                    await stopRecording();
                   } else {
                   await startRecording();
                  }
                  },
                 )
                  ],
                ),

                const SizedBox(height: 12),

                // ▶️ تشغيل / حذف
                if (audioAnswerFile != null)
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: Icon(isPlaying
                            ? Icons.stop
                            : Icons.play_arrow),
                        onPressed: playAudio,
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete,
                            color: Colors.red),
                        onPressed: deleteAudio,
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
                  final answerText =
                      answerController.text.trim();

                  if (answerText.isEmpty) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(
                      const SnackBar(
                          content:
                              Text('يرجى كتابة الرد')),
                    );
                    return;
                  }

                  try {
                    final audioPath =
                        audioAnswerFile?.path;

                    await LocalDB.updateAnswer(
                      q['id'],
                      answerText,
                      audioPath,
                      widget.expertId,
                      isSynced: 0,
                    );

                    final success =
                        await ApiService.answerQuestion(
                      q['id'],
                      answerText,
                      widget.expertId,
                      audioFile: audioAnswerFile,
                    );

                    if (success) {
                      await LocalDB.updateAnswer(
                        q['id'],
                        answerText,
                        audioPath,
                        widget.expertId,
                        isSynced: 1,
                      );

                      ScaffoldMessenger.of(context)
                          .showSnackBar(
                        const SnackBar(
                            content:
                                Text('تم إرسال الرد بنجاح')),
                      );
                    } else {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(
                        const SnackBar(
                          content: Text(
                              'تم حفظ الرد وسيتم إرساله لاحقاً'),
                        ),
                      );
                    }
                  } catch (_) {}

                  Navigator.pop(context);
                  _loadQuestions();
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

      // =============================
      // عنوان السؤال
      // =============================
      title: Text(
        q['question'],
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),

      // =============================
      // المحتوى السفلي
      // =============================
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // 🔊 زر تشغيل صوت الاستفسار (يظهر دائماً)
            if (q['question_audio_path'] != null &&
             File(q['question_audio_path']).existsSync())
             Row(
             children: [
            const Icon(Icons.volume_up, color: Colors.blue),
            const SizedBox(width: 6),
            TextButton(
             child: const Text(
              'صوت المزارع',
              style: TextStyle(fontWeight: FontWeight.bold),
             ),
             onPressed: () async {
             try {
              await player.stop();
              await player.play(
              DeviceFileSource(q['question_audio_path']),
              );
              } catch (e) {
              print("خطأ في تشغيل صوت الاستفسار: $e");
                }
              },
             ),
            ],
           ),
            // =============================
            // محتوى الرد (يظهر فقط في المجابة)
            // =============================
            if (answeredCard) ...[

              // 🔊 زر تشغيل صوت الرد
              if (q['answer_audio_path'] != null &&
               File(q['answer_audio_path']).existsSync())
               Row(
              children: [
              const Icon(Icons.play_circle_fill, color: Colors.green),
              const SizedBox(width: 6),
              TextButton(
              child: const Text(
              'صوت الخبير',
              style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () async {
             try {
              await player.stop();
              await player.play(
              DeviceFileSource(q['answer_audio_path']),
             );
             } catch (e) {
               print("خطأ في تشغيل صوت الرد: $e");
             }
             },
            ),
           ],
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
          ],
        ),
      ),

      // =============================
      // صورة السؤال
      // =============================
      leading: GestureDetector(
        onTap: () => _showFullImage(q['image_path']),
        child: Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            image: q['image_path'] != null &&
                    File(q['image_path']).existsSync()
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

      // =============================
      // زر الرد (لغير المجابة فقط)
      // =============================
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
