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

  // Lazy-loading / local media cache state
  final Set<int> _answerImagesLoaded = <int>{};
  final Set<int> _answerImagesLoading = <int>{};
  final Map<int, List<String>> _answerImagesCache = <int, List<String>>{};
  final Set<int> _mediaLoading = <int>{};
  

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
  if (mounted) {
    setState(() => loading = true);
  }

  // 1) اعرض البيانات المحلية فوراً.
  final localUnanswered = await LocalDB.getUnanswered();
  final localAnswered = await LocalDB.getAnswered();

  if (mounted) {
    setState(() {
      unanswered = localUnanswered;
      answered = localAnswered;
    });
  }

  try {
    // 2) جلب بيانات الأسئلة فقط.
    //    مهم: لا يتم تنزيل أي صورة أو صوت هنا.
    final data =
        await ApiService.getExpertDiagnoses(widget.expertId);

    final serverUnanswered =
        List<Map<String, dynamic>>.from(data['unanswered']);

    final serverAnswered =
        List<Map<String, dynamic>>.from(data['answered']);

    // 3) حفظ metadata فقط في SQLite.
    for (final q in [...serverUnanswered, ...serverAnswered]) {
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
    }

    // 4) إعادة قراءة SQLite بعد تحديث البيانات.
    final updatedUnanswered = await LocalDB.getUnanswered();
    final updatedAnswered = await LocalDB.getAnswered();

    if (!mounted) return;

    setState(() {
      unanswered = updatedUnanswered;
      answered = updatedAnswered;
      loading = false;
    });
  } catch (e) {
    debugPrint("Load questions error: $e");

    if (mounted) {
      setState(() => loading = false);
    }
  }
}

// ============================================================================
// Lazy Loading للوسائط
// ============================================================================

bool _isTrue(dynamic value) {
  return value == true || value == 1 || value == "1";
}

Future<String?> _ensureQuestionImage(Map<String, dynamic> q) async {
  final questionId = int.tryParse('${q['id']}');
  if (questionId == null || !_isTrue(q['has_image'])) return null;
  final id = questionId;

  final currentPath = q['image_path']?.toString();
  if (currentPath != null &&
      currentPath.isNotEmpty &&
      File(currentPath).existsSync()) {
    return currentPath;
  }

  final dir = await getApplicationDocumentsDirectory();
  final filePath = '${dir.path}/q_$id.jpg';
  final file = File(filePath);

  if (file.existsSync() && file.lengthSync() > 0) {
    await LocalDB.updateQuestionImagePath(id, filePath);
    return filePath;
  }

  if (_mediaLoading.contains(id)) {
    // ننتظر قليلاً إذا كان نفس الملف قيد التنزيل من ضغطة أخرى.
    for (int i = 0; i < 100; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (!_mediaLoading.contains(id)) break;
    }

    if (file.existsSync() && file.lengthSync() > 0) {
      await LocalDB.updateQuestionImagePath(id, filePath);
      return filePath;
    }
  }

  _mediaLoading.add(id);
  try {
    final path = await _downloadAndSaveFile(
      "${ApiService.baseUrl}/expert_question_image/$id",
      "q_$id.jpg",
    );

    if (path != null && path.isNotEmpty) {
      await LocalDB.updateQuestionImagePath(id, path);
      return path;
    }
  } finally {
    _mediaLoading.remove(id);
  }

  return null;
}

Future<String?> _ensureQuestionAudio(Map<String, dynamic> q) async {
  final questionId = int.tryParse('${q['id']}');
  if (questionId == null || !_isTrue(q['question_has_audio'])) return null;
  final id = questionId;

  final currentPath = q['question_audio_path']?.toString();
  if (currentPath != null &&
      currentPath.isNotEmpty &&
      File(currentPath).existsSync()) {
    return currentPath;
  }

  final dir = await getApplicationDocumentsDirectory();
  final filePath = '${dir.path}/q_$id.m4a';
  final file = File(filePath);

  if (file.existsSync() && file.lengthSync() > 0) {
    await LocalDB.updateQuestionAudioPath(id, filePath);
    return filePath;
  }

  final lockId = -id.abs() - 1000000;

  if (_mediaLoading.contains(lockId)) {
    for (int i = 0; i < 100; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (!_mediaLoading.contains(lockId)) break;
    }

    if (file.existsSync() && file.lengthSync() > 0) {
      await LocalDB.updateQuestionAudioPath(id, filePath);
      return filePath;
    }
  }

  _mediaLoading.add(lockId);
  try {
    final path = await _downloadAndSaveFile(
      "${ApiService.baseUrl}/expert_question_audio/$id",
      "q_$id.m4a",
    );

    if (path != null && path.isNotEmpty) {
      await LocalDB.updateQuestionAudioPath(id, path);
      return path;
    }
  } finally {
    _mediaLoading.remove(lockId);
  }

  return null;
}

Future<String?> _ensureAnswerAudio(Map<String, dynamic> q) async {
  final questionId = int.tryParse('${q['id']}');
  if (questionId == null || !_isTrue(q['answer_has_audio'])) return null;
  final id = questionId;

  final currentPath = q['answer_audio_path']?.toString();
  if (currentPath != null &&
      currentPath.isNotEmpty &&
      File(currentPath).existsSync()) {
    return currentPath;
  }

  final dir = await getApplicationDocumentsDirectory();
  final filePath = '${dir.path}/a_$id.m4a';
  final file = File(filePath);

  if (file.existsSync() && file.lengthSync() > 0) {
    await LocalDB.updateAnswerAudioPath(id, filePath);
    return filePath;
  }

  final lockId = -id.abs() - 2000000;

  if (_mediaLoading.contains(lockId)) {
    for (int i = 0; i < 100; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (!_mediaLoading.contains(lockId)) break;
    }

    if (file.existsSync() && file.lengthSync() > 0) {
      await LocalDB.updateAnswerAudioPath(id, filePath);
      return filePath;
    }
  }

  _mediaLoading.add(lockId);
  try {
    final path = await _downloadAndSaveFile(
      "${ApiService.baseUrl}/expert_answer_audio/$id",
      "a_$id.m4a",
    );

    if (path != null && path.isNotEmpty) {
      await LocalDB.updateAnswerAudioPath(id, path);
      return path;
    }
  } finally {
    _mediaLoading.remove(lockId);
  }

  return null;
}

Future<void> _playQuestionAudio(Map<String, dynamic> q) async {
  try {
    final path = await _ensureQuestionAudio(q);

    if (!mounted) return;

    if (path == null || !File(path).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تحميل صوت الاستفسار')),
      );
      return;
    }

    await player.stop();
    await player.play(DeviceFileSource(path));
  } catch (e) {
    debugPrint("Question audio error: $e");
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدث خطأ أثناء تشغيل صوت الاستفسار')),
      );
    }
  }
}

Future<void> _playAnswerAudio(Map<String, dynamic> q) async {
  try {
    final path = await _ensureAnswerAudio(q);

    if (!mounted) return;

    if (path == null || !File(path).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تحميل صوت الخبير')),
      );
      return;
    }

    await player.stop();
    await player.play(DeviceFileSource(path));
  } catch (e) {
    debugPrint("Answer audio error: $e");
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدث خطأ أثناء تشغيل صوت الخبير')),
      );
    }
  }
}

Future<void> _openQuestionImage(Map<String, dynamic> q) async {
  try {
    final path = await _ensureQuestionImage(q);

    if (!mounted) return;

    if (path == null || !File(path).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تحميل صورة الاستفسار')),
      );
      return;
    }

    _showFullImage(path);
  } catch (e) {
    debugPrint("Question image error: $e");
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدث خطأ أثناء تحميل الصورة')),
      );
    }
  }
}

Future<List<String>> _loadAnswerImagesOnDemand(int questionId, int expectedImageCount) async {
  if (_answerImagesLoaded.contains(questionId)) {
    return _answerImagesCache[questionId] ?? <String>[];
  }

  if (_answerImagesLoading.contains(questionId)) {
    for (int i = 0; i < 150; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (!_answerImagesLoading.contains(questionId)) break;
    }
    return _answerImagesCache[questionId] ?? <String>[];
  }

  _answerImagesLoading.add(questionId);

  try {
    // إذا كانت الصور موجودة محلياً بالفعل، نستخدمها بدون اتصال.
    final localImages = await LocalDB.getAnswerImages(questionId);
    final validLocalImages = localImages
        .where((path) => File(path).existsSync() && File(path).lengthSync() > 0)
        .toList();

    if (expectedImageCount > 0 &&
        validLocalImages.length == expectedImageCount) {
      _answerImagesCache[questionId] = validLocalImages;
      _answerImagesLoaded.add(questionId);
      return validLocalImages;
    }

    // أول اتصال بالسيرفر يحدث فقط بعد ضغط المستخدم على الصور.
    final response = await http.get(
      Uri.parse(
        "${ApiService.baseUrl}/expert_answer_images/$questionId",
      ),
    );

    if (response.statusCode != 200) {
      throw Exception(
        "Failed to get answer images: ${response.statusCode}",
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw Exception("Invalid answer images response");
    }

    final downloadedPaths = <String>[];

    for (final img in decoded) {
      final imageId = img["id"];
      if (imageId == null) continue;

      final dir = await getApplicationDocumentsDirectory();
      final filePath =
          '${dir.path}/answer_${questionId}_$imageId.jpg';

      final file = File(filePath);

      String? path;
      if (file.existsSync() && file.lengthSync() > 0) {
        path = filePath;
      } else {
        path = await _downloadAndSaveFile(
          "${ApiService.baseUrl}/expert_answer_image/$imageId",
          "answer_${questionId}_$imageId.jpg",
        );
      }

      if (path != null && path.isNotEmpty) {
        downloadedPaths.add(path);
      }
    }

    await LocalDB.clearAnswerImages(questionId);

    for (final path in downloadedPaths) {
      await LocalDB.insertAnswerImage(questionId, path);
    }

    _answerImagesCache[questionId] = downloadedPaths;
    _answerImagesLoaded.add(questionId);

    return downloadedPaths;
  } catch (e) {
    debugPrint(
      "Lazy answer images error for $questionId: $e",
    );
    return _answerImagesCache[questionId] ?? <String>[];
  } finally {
    _answerImagesLoading.remove(questionId);
  }
}

Widget _buildAnswerImagesLazy(int questionId, int imageCount) {
  final images = _answerImagesCache[questionId] ?? <String>[];
  final isLoading = _answerImagesLoading.contains(questionId);

  if (images.isEmpty && !_answerImagesLoaded.contains(questionId)) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: OutlinedButton.icon(
        icon: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.photo_library_outlined),
        label: Text(
          isLoading
              ? 'جاري تحميل الصور...'
              : 'عرض الصور${imageCount > 0 ? ' ($imageCount)' : ''}',
        ),
        onPressed: isLoading
            ? null
            : () async {
                await _loadAnswerImagesOnDemand(questionId, imageCount);
                if (mounted) setState(() {});
              },
      ),
    );
  }

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
              errorBuilder: (_, __, ___) => Container(
                width: 120,
                height: 120,
                color: Colors.grey.shade200,
                child: const Icon(Icons.broken_image),
              ),
            ),
          ),
        );
      }).toList(),
    ),
  );
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
	Widget _buildMediaPlaceholder(IconData icon) {
  return Center(
    child: Icon(
      icon,
      size: 38,
      color: Colors.grey.shade600,
    ),
  );
}

Widget _buildQuestionCard(
  Map<String, dynamic> q, {
  bool answeredCard = false,
}) {
  final questionId = int.tryParse('${q["id"]}') ?? 0;

  final questionKey = _questionKeys.putIfAbsent(
    questionId,
    () => GlobalKey(),
  );

  Widget? quoteWidget;

  if (q["parent_question_id"] != null) {
    final parentId = int.tryParse('${q["parent_question_id"]}');

    if (parentId != null) {
      final parentList = [...answered, ...unanswered];

      final parentItems = parentList.where(
        (e) => int.tryParse('${e["id"]}') == parentId,
      );

      if (parentItems.isNotEmpty) {
        final parent = parentItems.first;

        final parentAnswer =
            (parent["answer"] ?? "").toString().trim();

        final parentImageCount =
            int.tryParse('${parent["answer_image_count"] ?? 0}') ?? 0;

        quoteWidget = GestureDetector(
          onTap: () => _openQuotedQuestion(parentId),
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

                if (parentAnswer.isNotEmpty)
                  Text(
                    parentAnswer,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),

                if (parentImageCount > 0)
                  _buildAnswerImagesLazy(
                    parentId,
                    parentImageCount,
                  ),

                if (_isTrue(parent["answer_has_audio"]))
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      icon: const Icon(
                        Icons.play_circle_fill,
                        color: Colors.green,
                      ),
                      label: const Text('صوت الخبير'),
                      onPressed: () => _playAnswerAudio(parent),
                    ),
                  ),
              ],
            ),
          ),
        );
      }
    }
  }

  return Container(
    key: questionKey,
    child: Card(
      margin: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),

        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (quoteWidget != null) quoteWidget!,

            Text(
              q['question']?.toString() ?? '',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),

        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // صوت الاستفسار:
              // لا يتم تنزيله هنا، وإنما عند الضغط فقط.
              if (_isTrue(q['question_has_audio']))
                Row(
                  children: [
                    const Icon(
                      Icons.volume_up,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 6),
                    TextButton.icon(
                      icon: const Icon(
                        Icons.play_circle_outline,
                      ),
                      label: const Text(
                        'صوت المزارع',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: () => _playQuestionAudio(q),
                    ),
                  ],
                ),

              if (answeredCard) ...[
                if (_isTrue(q['answer_has_audio']))
                  Row(
                    children: [
                      const Icon(
                        Icons.play_circle_fill,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 6),
                      TextButton.icon(
                        icon: const Icon(Icons.play_arrow),
                        label: const Text(
                          'صوت الخبير',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: () => _playAnswerAudio(q),
                      ),
                    ],
                  ),

                const Divider(),

                if ((int.tryParse(
                          '${q['answer_image_count'] ?? 0}',
                        ) ??
                        0) >
                    0)
                  _buildAnswerImagesLazy(
                    questionId,
                    int.tryParse(
                          '${q['answer_image_count'] ?? 0}',
                        ) ??
                        0,
                  ),

                Text(
                  'الإجابة (${q['expert_name'] ?? 'مجهول'}): '
                  '${q['answer'] ?? "لا توجد"}',
                ),

                const SizedBox(height: 4),

                Text(
                  '📅 تاريخ الرد: '
                  '${q['diagnosis_date'] ?? "غير متاح"}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.grey,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  '📅 تاريخ الاستفسار: '
                  '${q['question_date'] ?? "غير متاح"}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.grey,
                  ),
                ),
              ],
            ],
          ),
        ),

        // صورة السؤال:
        // تظهر كـ placeholder ولا يتم تنزيلها إلا عند الضغط.
        leading: GestureDetector(
          onTap: _isTrue(q['has_image'])
              ? () => _openQuestionImage(q)
              : null,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey.shade200,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: q['image_path'] != null &&
                      q['image_path'].toString().isNotEmpty &&
                      File(q['image_path']).existsSync()
                  ? Image.file(
                      File(q['image_path']),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _buildMediaPlaceholder(
                        Icons.broken_image,
                      ),
                    )
                  : _buildMediaPlaceholder(
                      _isTrue(q['has_image'])
                          ? Icons.download
                          : Icons.image_not_supported,
                    ),
            ),
          ),
        ),

        trailing: !answeredCard
            ? IconButton(
                icon: const Icon(
                  Icons.reply,
                  color: Colors.green,
                  size: 28,
                ),
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
