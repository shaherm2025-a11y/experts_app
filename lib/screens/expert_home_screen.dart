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
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:image_picker/image_picker.dart';

class ExpertHomeScreen extends StatefulWidget {
  final int expertId;

  const ExpertHomeScreen({Key? key, required this.expertId})
      : super(key: key);

  @override
  State<ExpertHomeScreen> createState() => _ExpertHomeScreenState();
}

class _ExpertHomeScreenState extends State<ExpertHomeScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> unanswered = [];
  List<Map<String, dynamic>> answered = [];
  bool loading = true;
  late TabController _tabController;
  final Map<int, GlobalKey> _questionKeys = {};
  final ScrollController _answeredScrollController =
    ScrollController();
  final AudioPlayer player = AudioPlayer();
  final AudioRecorder record = AudioRecorder();
  Timer? _timer;
  

  @override
  void initState() {
    super.initState();
	_tabController = TabController(
      length: 2,
      vsync: this,
    );
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
    _tabController.dispose();

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

    final audioFile = q['answer_audio_path'] != null
        ? File(q['answer_audio_path'])
        : null;


    final imageFiles = (await LocalDB.getAnswerImages(q["id"]))
      .map((path) => File(path))
      .toList();

    final success = await ApiService.answerQuestion(
      q['id'],
      q['answer'] ?? "",
      q['expert_id'],   // ✅ رقم الخبير الصحيح لكل رد
      audioFile: audioFile,
      imageFiles: imageFiles, // ✅ الجديد
    );

    if (success) {
      await LocalDB.updateAnswer(
        q['id'],
        q['answer'],
        q['answer_audio_path'],
        q['expert_id'],
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

          // 3️⃣ حفظ البيانات + تحميل الملفات
        for (var q in [...serverUnanswered, ...serverAnswered]) {

          await LocalDB.insertOrUpdateQuestion({
           "id": q["id"],
           "question": q["question"],
           "answer": q["answer"],
		   "parent_question_id": q["parent_question_id"],
           "expert_name": q["expert_name"],
           "status": q["status"],
           "question_date": q["question_date"],
           "diagnosis_date": q["diagnosis_date"],

           "has_image": q["has_image"],
           "question_has_audio": q["question_has_audio"],
           "answer_has_audio": q["answer_has_audio"],
		   "answer_image_count": q["answer_image_count"],
          });

         // ===== تحميل صورة السؤال =====
        if (q["has_image"] == 1 || q["has_image"] == true) {

         try {

           final dir =
             await getApplicationDocumentsDirectory();

           final filePath = '${dir.path}/q_${q['id']}.jpg';
           final file = File(filePath);

           if (!file.existsSync()) {

           final imagePath = await _downloadAndSaveFile(
             "${ApiService.baseUrl}/expert_question_image/${q['id']}",
             "q_${q['id']}.jpg",
            );

           if (imagePath != null &&
             imagePath.isNotEmpty) {

             await LocalDB.updateQuestionImagePath(
               q['id'], imagePath);
             }
            }

           } catch (_) {
           debugPrint("No image for question ${q['id']}");
           }
          }

         // ===== تحميل صوت السؤال =====
        if (q["question_has_audio"] == true || q["question_has_audio"] == 1) {

          try {

         final dir =
           await getApplicationDocumentsDirectory();

         final filePath = '${dir.path}/q_${q['id']}.m4a';
         final file = File(filePath);

         if (!file.existsSync()) {

           final audioPath = await _downloadAndSaveFile(
           "${ApiService.baseUrl}/expert_question_audio/${q['id']}",
           "q_${q['id']}.m4a",
          );

          if (audioPath != null &&
            audioPath.isNotEmpty) {

             await LocalDB.updateQuestionAudioPath(
               q['id'], audioPath);
        }
      }

       } catch (_) {
        debugPrint(
          "No question audio for id ${q['id']}");
      }
   }

  // ===== تحميل صوت الإجابة =====
  if (q["answer_has_audio"] == true || q["answer_has_audio"] == 1) {

    try {

      final dir =
          await getApplicationDocumentsDirectory();

      final filePath = '${dir.path}/a_${q['id']}.m4a';
      final file = File(filePath);

      if (!file.existsSync()) {

        final answerAudioPath =
            await _downloadAndSaveFile(
          "${ApiService.baseUrl}/expert_answer_audio/${q['id']}",
          "a_${q['id']}.m4a",
        );

        if (answerAudioPath != null &&
            answerAudioPath.isNotEmpty) {

          await LocalDB.updateAnswerAudioPath(
              q['id'], answerAudioPath);
        }
      }

    } catch (_) {
      debugPrint(
          "No answer audio for id ${q['id']}");
    }
  }
  
  // ===== تحميل صورة الإجابة =====
// ===== مزامنة صور الإجابة =====
final serverImageCount =
    int.tryParse(
      "${q["answer_image_count"] ?? 0}",
    ) ?? 0;

if (serverImageCount > 0) {
  try {
    // 1️⃣ نقرأ الصور الموجودة محليًا أولاً
    final localImages =
        await LocalDB.getAnswerImages(q["id"]);

    // 2️⃣ نتحقق أن الملفات المحلية موجودة فعليًا
    final validLocalImages = localImages
        .where(
          (path) => File(path).existsSync(),
        )
        .toList();

    debugPrint(
      "Answer images for ${q["id"]}: "
      "local=${validLocalImages.length}, "
      "server=$serverImageCount",
    );

    // 3️⃣ إذا الصور المحلية كاملة، لا نذهب للسيرفر
    if (validLocalImages.length == serverImageCount) {

      debugPrint(
        "Using local answer images for "
        "question ${q["id"]}",
      );

    } else {

      // 4️⃣ الصور ناقصة أو غير موجودة
      debugPrint(
        "Downloading answer images for "
        "question ${q["id"]}",
      );

      final response = await http.get(
        Uri.parse(
          "${ApiService.baseUrl}/expert_answer_images/${q['id']}",
        ),
      );

      if (response.statusCode != 200) {
        throw Exception(
          "Failed to get answer images",
        );
      }

      final List images =
          jsonDecode(response.body);

      // 5️⃣ فقط هنا نحذف الصور القديمة
      await LocalDB.clearAnswerImages(
        q["id"],
      );

      // 6️⃣ تنزيل الصور الجديدة
      for (final img in images) {

        final imageId = img["id"];

        final imagePath =
            await _downloadAndSaveFile(
          "${ApiService.baseUrl}/expert_answer_image/$imageId",
          "answer_${q['id']}_$imageId.jpg",
        );

        if (imagePath != null &&
            imagePath.isNotEmpty) {

          await LocalDB.insertAnswerImage(
            q["id"],
            imagePath,
          );
        }
      }
    }

  } catch (e) {

    debugPrint(
      "Answer images sync error "
      "for id ${q['id']}: $e",
    );
  }
}
}

// 4️⃣ إعادة قراءة SQLite بعد التحديث
final updatedUnanswered =
    await LocalDB.getUnanswered();

final updatedAnswered =
    await LocalDB.getAnswered();

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
void _jumpToQuestion(int parentQuestionId) {

  _tabController.animateTo(1);

  Future.delayed(
    const Duration(milliseconds: 400),
    () {

      final key =
          _questionKeys[parentQuestionId];

      if (key == null) return;

      final context =
          key.currentContext;

      if (context == null) return;

      Scrollable.ensureVisible(
        context,
        duration:
            const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );

    },
  );
}
Future<void> _openQuotedQuestion(
    int parentQuestionId) async {

  _jumpToQuestion(parentQuestionId);
}
	
Future<void> _showAnswerDialog(Map<String, dynamic> q) async {
    TextEditingController answerController =
        TextEditingController(text: q['answer'] ?? '');
    bool isSending = false;
    bool isRecording = false;
    bool isPlaying = false;
    File? audioAnswerFile;
    Duration duration = Duration.zero;
	List<File> answerImages = [];
    final ImagePicker picker = ImagePicker();
	
//Future<void> pickImage() async {

  // final picked = await picker.pickMultiImage();

   //if (picked.isEmpty) return;

    //setState(() {

   // answerImages.clear();

   // answerImages.addAll(
    //  picked.map((e) => File(e.path)),
   // );

  //});

//}


    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
		Future<void> pickImage() async {
          try {
           final picked = await picker.pickMultiImage(
           imageQuality: 90,
         );

        if (picked.isEmpty) return;

         setState(() {
         answerImages.addAll(
         picked.map((e) => File(e.path)),
         );
        });
       } catch (e) {
       debugPrint("Image picker error: $e");

       ScaffoldMessenger.of(context).showSnackBar(
       const SnackBar(
         content: Text('حدث خطأ أثناء اختيار الصور'),
        ),
       );
      }
     }

		
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
                 mainAxisAlignment: MainAxisAlignment.spaceEvenly,
             children: [

            // 🎤 تسجيل صوت
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
          ),

            // 🖼️ اختيار صورة
           ElevatedButton.icon(
           icon: const Icon(Icons.image),
           label: const Text('صورة'),
           style: ElevatedButton.styleFrom(
           backgroundColor: Colors.blue,
           ),
           onPressed: pickImage,
            ),
           ],
          ),
           // عرض الصورة
          // عرض الصور المختارة
if (answerImages.isNotEmpty)
  Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'الصور المختارة (${answerImages.length})',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 8),

        SizedBox(
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: answerImages.length,
            separatorBuilder: (_, __) =>
                const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final file = answerImages[index];

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  GestureDetector(
                    onTap: () {
                      _showFullImage(file.path);
                    },
                    child: ClipRRect(
                      borderRadius:
                          BorderRadius.circular(10),
                      child: Image.file(
                        file,
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),

                  Positioned(
                    top: -5,
                    right: -5,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          answerImages.removeAt(index);
                        });
                      },
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    ),
  ),            const SizedBox(height: 12),
				

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
  onPressed: isSending
      ? null
      : () async {
          setState(() {
            isSending = true;
          });

          final answerText =
              answerController.text.trim().isEmpty
                  ? " "
                  : answerController.text.trim();

          final hasAudio = audioAnswerFile != null;
          final hasImage = answerImages.isNotEmpty;

          if (answerText.trim().isEmpty &&
              !hasAudio &&
              !hasImage) {
            setState(() {
              isSending = false;
            });

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'يرجى كتابة الرد أو تسجيل الصوت',
                ),
              ),
            );
            return;
          }

          try {
            final audioPath = audioAnswerFile?.path;

            await LocalDB.updateAnswer(
              q['id'],
              answerText,
              audioPath,
              widget.expertId,
              isSynced: 0,
            );

            await LocalDB.clearAnswerImages(q['id']);

            for (final image in answerImages) {
              await LocalDB.insertAnswerImage(
                q['id'],
                image.path,
              );
            }

            final success =
                await ApiService.answerQuestion(
              q['id'],
              answerText,
              widget.expertId,
              audioFile: audioAnswerFile,
              imageFiles: answerImages,
            );

            if (success) {
              await LocalDB.updateAnswer(
                q['id'],
                answerText,
                audioPath,
                widget.expertId,
                isSynced: 1,
              );

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تم إرسال الرد بنجاح'),
                  ),
                );
              }

              if (context.mounted) {
                Navigator.pop(context);
              }

              _loadQuestions();

            } else {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'تم حفظ الرد وسيتم إرساله لاحقاً',
                    ),
                  ),
                );
              }

              if (context.mounted) {
                Navigator.pop(context);
              }

              _loadQuestions();
            }

          } catch (e) {
            debugPrint(
              "Answer sending error: $e",
            );

            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'حدث خطأ أثناء إرسال الرد',
                  ),
                ),
              );
            }

            // نسمح بالمحاولة مرة أخرى فقط
            setState(() {
              isSending = false;
            });
          }
        },
  child: isSending
      ? const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white,
          ),
        )
      : const Text('إرسال'),
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
	void _showNetworkImage(String imageUrl) {
  showDialog(
    context: context,
    builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      child: InteractiveViewer(
        panEnabled: true,
        minScale: 0.5,
        maxScale: 5.0,
        child: Image.network(
          imageUrl,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) {
            return const Center(
              child: Icon(
                Icons.image_not_supported,
                size: 80,
                color: Colors.white,
              ),
            );
          },
        ),
      ),
    ),
  );
}
Widget _buildQuestionCard(Map<String, dynamic> q, {bool answeredCard = false}) {
  final questionKey =
     _questionKeys.putIfAbsent(
      q["id"],
      () => GlobalKey(),
    );
 
  Widget? quoteWidget;

if (q["parent_question_id"] != null) {
   final parentList = [
    ...answered,
    ...unanswered
  ];

  final parentItems = parentList.where(
    (e) => e["id"] == q["parent_question_id"]
  );

  if (parentItems.isNotEmpty) {

    final parent = parentItems.first;

 quoteWidget = GestureDetector(
  onTap: () {
    _openQuotedQuestion(
      q["parent_question_id"],
    );
  },
  child: Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Colors.green.shade50,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: Colors.green.shade200,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        const Row(
          children: [
            Icon(Icons.reply, size: 16),
            SizedBox(width: 4),
            Text(
              "متابعة لاستفسار سابق",
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),

        const SizedBox(height: 6),
if ((parent["answer"] ?? "").toString().isNotEmpty)
  Text(
    parent["answer"],
    maxLines: 3,
    overflow: TextOverflow.ellipsis,
  ),

const SizedBox(height: 8),

FutureBuilder<List<String>>(
  future: LocalDB.getAnswerImages(parent["id"]),
  builder: (context, snapshot) {

    if (!snapshot.hasData || snapshot.data!.isEmpty) {
      return const SizedBox();
    }

    final images = snapshot.data!;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: images.map((path) {

  return GestureDetector(
    onTap: () => _showFullImage(path),
    child: Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        image: DecorationImage(
          image: FileImage(File(path)),
          fit: BoxFit.cover,
        ),
      ),
    ),
  );

}).toList(),
    );
  },
),

            if (parent["answer_audio_path"] != null && File(parent["answer_audio_path"]).existsSync())
              IconButton(
                icon: const Icon(
                  Icons.play_circle_fill,
                  color: Colors.green,
                  size: 34,
                ),
                onPressed: () async {

                  await player.stop();

                  await player.play(
                   DeviceFileSource(
                     parent["answer_audio_path"],
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
 return Container(
  key: questionKey,
  child: Card(
    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    elevation: 4,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: ListTile(
      contentPadding: const EdgeInsets.all(12),

      // =============================
      // عنوان السؤال
      // =============================
	  
      title: Column(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [

       if (quoteWidget != null)
         quoteWidget,

         Text(
          q['question'],
          style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          ),
        ),
      ],
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

FutureBuilder<List<String>>(
  future: LocalDB.getAnswerImages(q['id']),
  builder: (context, snapshot) {

    if (!snapshot.hasData) {
      return const SizedBox();
    }

    final images = snapshot.data!;

    if (images.isEmpty) {
      return const SizedBox();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: images.map((path) {

  return GestureDetector(
    onTap: () => _showFullImage(path),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.file(
        File(path),
        width: 120,
        height: 120,
        fit: BoxFit.cover,
      ),
    ),
  );

}).toList(),
      ),
    );
  },
),
              // ✍️ نص الإجابة
            Text(
               'الإجابة (${q['expert_name'] ?? 'مجهول'}): ${q['answer'] ?? "لا توجد"}',
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
   ), 	
  );
}
	@override
Widget build(BuildContext context) {

  if (loading) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  return Scaffold(
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
                  isAdmin: false,
                ),
              ),
            );

          },
        ),

      ],

      bottom: TabBar(
        controller: _tabController,
        indicatorColor: Colors.white,
        indicatorWeight: 4,
        tabs: const [

          Tab(
            text: 'لم يتم الرد عليها',
          ),

          Tab(
            text: 'تم الرد عليها',
          ),

        ],
      ),
    ),

    body: TabBarView(
      controller: _tabController,

      children: [

        // غير المجابة
        RefreshIndicator(
          onRefresh: _loadQuestions,

          child: ListView.builder(
            padding: const EdgeInsets.only(top: 8),

            itemCount: unanswered.length,

            itemBuilder: (context, index) {

              return _buildQuestionCard(
                unanswered[index],
              );

            },
          ),
        ),

        // المجابة
        RefreshIndicator(
          onRefresh: _loadQuestions,

          child: ListView.builder(
		    controller: _answeredScrollController,
            padding: const EdgeInsets.only(top: 8),

            itemCount: answered.length,

            itemBuilder: (context, index) {

              return _buildQuestionCard(
                answered[index],
                answeredCard: true,
              );

            },
          ),
        ),

      ],
    ),
  );
}
}
