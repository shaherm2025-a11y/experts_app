import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/expert.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http_parser/http_parser.dart';

class ApiService {
//   static const String baseUrl = "https://mohashaher-backend-supaspace.hf.space";
 static const String baseUrl = "https://mohashaher-mobile-backend.hf.space";
  //static const String baseUrl = "https://mohashaher-plant-diag-final-server.hf.space";
 //static const String baseUrl = "http://localhost:8000";

  // تسجيل دخول الخبير
  static Future<Map<String, dynamic>> loginExpert(String name, String password) async {
  try {
    var response = await http
        .post(
          Uri.parse("$baseUrl/expert_login"),
          body: {"name": name, "password": password},
        )
        .timeout(const Duration(seconds: 10)); // ⏳ مهلة 10 ثوانٍ

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      return {"status": "error", "message": "خطأ في الخادم"};
    }
  } catch (e) {
    return {"status": "error", "message": e.toString()};
  }
}

  // جلب كل الخبراء (للمدير)  
  static Future<List<Expert>> getExperts() async {
    final response = await http.get(Uri.parse('$baseUrl/get_experts'));
    final List data = json.decode(response.body);
    return data.map((e) => Expert.fromJson(e)).toList();
  }

  // إضافة خبير جديد
  static Future<bool> addExpert(Expert expert) async {
    final response = await http.post(
      Uri.parse('$baseUrl/add_expert'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(expert.toJson()),
    );
    return response.statusCode == 200;
  }

  // حذف خبير
  static Future<bool> deleteExpert(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/delete_expert/$id'));
    return response.statusCode == 200;
  }

  // ===============================
  // 🔹 واجهة الخبير (الأسئلة والإجابات)
  // ===============================

  // جلب الأسئلة للخبير (مجاوبة وغير مجاوبة)
  static Future<Map<String, dynamic>> getExpertDiagnoses(int expertId) async {
    final response = await http.get(Uri.parse('$baseUrl/expert_diagnoses/$expertId'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception("فشل في تحميل الأسئلة");
    }
  }

static Future<bool> answerQuestion(
  int questionId,
  String answerText,
  int expertId, {
  File? audioFile,
  List<File>? imageFiles,
}) async {
  try {
    final uri = Uri.parse(
      "$baseUrl/answer_question/$questionId",
    );

    final request = http.MultipartRequest(
      'PUT',
      uri,
    );

    // =========================
    // البيانات النصية
    // =========================
    request.fields['answer'] = answerText;
    request.fields['expert_id'] = expertId.toString();

    // =========================
    // الصوت
    // =========================
    if (audioFile != null && await audioFile.exists()) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'answer_audio',
          audioFile.path,
        ),
      );

      print("Sending audio: ${audioFile.path}");
    }

    // =========================
    // الصور المتعددة
    // =========================
    if (imageFiles != null && imageFiles.isNotEmpty) {
      for (final imageFile in imageFiles) {
        if (await imageFile.exists()) {
          request.files.add(
            await http.MultipartFile.fromPath(
              'answer_images',
              imageFile.path,
            ),
          );

          print("Sending answer image: ${imageFile.path}");
        }
      }
    } else {
      print("No answer images selected");
    }

    // =========================
    // إرسال الطلب
    // =========================
    final response = await request.send();

    final responseBody = await response.stream.bytesToString();

    print("STATUS: ${response.statusCode}");
    print("RESPONSE: $responseBody");

    return response.statusCode == 200;
  } catch (e) {
    print("Exception sending answer: $e");
    return false;
  }
}
// تعديل بيانات خبير (للخبير أو للمدير)
  static Future<bool> updateExpert({
  required int expertId,
  String? name,
  String? email,
  String? password,
  String? jobTitle,
  int? isAdmin,
  int? canViewAll,
}) async {
  final response = await http.put(
    Uri.parse('$baseUrl/update_expert/$expertId'),
    headers: {'Content-Type': 'application/json'},
    body: json.encode({
      if (name != null) 'name': name,
      if (email != null) 'email': email,
      if (password != null) 'password': password,
      if (jobTitle != null) 'job_title': jobTitle,
      if (isAdmin != null) 'is_admin': isAdmin,
      if (canViewAll != null) 'can_view_all': canViewAll,
    }),
  );
  return response.statusCode == 200;
}
static Future<bool> editAnswer(
  int questionId,
  String answerText,
  int expertId, {
  File? audioFile,
  List<File>? imageFiles,
}) async {
  try {
    final request = http.MultipartRequest(
      'PUT',
      Uri.parse(
        '$baseUrl/edit_answer/$questionId',
      ),
    );

    request.fields['answer'] = answerText;
    request.fields['expert_id'] = expertId.toString();

    // =========================
    // AUDIO
    // =========================

    if (audioFile != null &&
        await audioFile.exists()) {
      debugPrint(
        "EDIT AUDIO: ${audioFile.path}",
      );

      request.files.add(
        await http.MultipartFile.fromPath(
          'answer_audio',
          audioFile.path,
        ),
      );
    }

    // =========================
    // IMAGES
    // =========================

    debugPrint(
      "EDIT IMAGE FILES COUNT: "
      "${imageFiles?.length ?? 0}",
    );

    if (imageFiles != null) {
  for (final image in imageFiles) {
    final exists = await image.exists();

    debugPrint("IMAGE PATH: ${image.path}");
    debugPrint("IMAGE EXISTS: $exists");

    if (!exists) {
      continue;
    }

    final extension =
        image.path.toLowerCase().split('.').last;

    MediaType? contentType;

    if (extension == 'jpg' || extension == 'jpeg') {
      contentType = MediaType('image', 'jpeg');
    } else if (extension == 'png') {
      contentType = MediaType('image', 'png');
    } else if (extension == 'webp') {
      contentType = MediaType('image', 'webp');
    }

    request.files.add(
      await http.MultipartFile.fromPath(
        'answer_images',
        image.path,
        contentType: contentType,
      ),
    );

    debugPrint(
      "IMAGE ADDED: ${image.path} "
      "TYPE: $contentType",
    );
  }
}

    // =========================
    // REQUEST DEBUG
    // =========================

    debugPrint(
      "EDIT REQUEST FIELDS: ${request.fields}",
    );

    debugPrint(
      "EDIT REQUEST FILES: ${request.files.length}",
    );

    for (final file in request.files) {
      debugPrint(
        "REQUEST FILE => "
        "field=${file.field}, "
        "filename=${file.filename}, "
        "length=${file.length}, "
        "contentType=${file.contentType}",
      );
    }

    // =========================
    // SEND
    // =========================

    final response = await request.send();

    final body =
        await response.stream.bytesToString();

    debugPrint(
      "EDIT STATUS: ${response.statusCode}",
    );

    debugPrint(
      "EDIT RESPONSE: $body",
    );

    return response.statusCode == 200;
  } catch (e) {
    debugPrint(
      "editAnswer error: $e",
    );

    return false;
  }
}
static Future<void> saveFcmToken({
  required int userId,
  required String role,
  required String token,
}) async {

  await http.post(
    Uri.parse("$baseUrl/save_fcm_token"),
    body: {
      "user_id": userId.toString(),
      "role": role,
      "fcm_token": token,
    },
  );
}

}