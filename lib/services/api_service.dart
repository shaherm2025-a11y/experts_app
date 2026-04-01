import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/expert.dart';
import 'dart:io';

class ApiService {
   static const String baseUrl = "https://mohashaher-backend-supaspace.hf.space";
  //static const String baseUrl = "https://mohashaher-mobile-backend.hf.space";
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
  int expertId,
  {File? audioFile, File? imageFile}
) async {
  try {
    var uri = Uri.parse("$baseUrl/answer_question/$questionId");

    var request = http.MultipartRequest('PUT', uri);

    // 🔹 الحقول النصية
    request.fields['answer'] = answerText;
    request.fields['expert_id'] = expertId.toString();

    // 🎤 الصوت
    if (audioFile != null && await audioFile.exists()) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'answer_audio',
          audioFile.path,
        ),
      );
    }

    // 🖼️ الصورة (🔥 قبل الإرسال)
    if (imageFile != null && await imageFile.exists()) {

      print("Sending image: ${imageFile.path}");

      request.files.add(
        await http.MultipartFile.fromPath(
          'answer_image', // ✅ الاسم الصحيح
          imageFile.path,
        ),
      );
    } else {
      print("No image selected");
    }

    // 🚀 الإرسال بعد إضافة كل شيء
    var response = await request.send();

    print("STATUS: ${response.statusCode}");

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