import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class LocalDB {
  static Database? _database;

  // ===============================
  // 🔹 الحصول على قاعدة البيانات
  // ===============================
  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  // ===============================
  // 🔹 إنشاء قاعدة البيانات
  // ===============================
  static Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, "expert_local.db");

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  // ===============================
  // 🔹 إنشاء جدول الأسئلة
  // ===============================
  static Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE questions (
        id INTEGER PRIMARY KEY,
        question TEXT,
        answer TEXT,
        image_path TEXT,
        question_audio_path TEXT,
        answer_audio_path TEXT,
        status INTEGER,
        question_date TEXT,
        created_at TEXT
      )
    ''');
  }

  // ===============================
  // 🔹 إضافة سؤال جديد
  // ===============================
  static Future<int> insertQuestion(Map<String, dynamic> data) async {
    final db = await database;

    return await db.insert(
      "questions",
      {
        "id": data["id"],
        "question": data["question"],
        "answer": data["answer"],
        "image_path": data["image_path"],
        "question_audio_path": data["question_audio_path"],
        "answer_audio_path": data["answer_audio_path"],
        "status": data["status"] ?? 0,

        // ⭐ تاريخ السؤال
        "question_date":
            data["question_date"] ?? DateTime.now().toIso8601String(),

        "created_at": DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ===============================
  // 🔹 تحديث الرد (نص + صوت)
  // ===============================
  static Future<void> updateAnswer(
      int id, String answer, String? audioPath) async {
    final db = await database;

    await db.update(
      "questions",
      {
        "answer": answer,
        "answer_audio_path": audioPath,
        "status": 1,
      },
      where: "id = ?",
      whereArgs: [id],
    );
  }

  // ===============================
  // 🔹 تحديث مسار صوت السؤال
  // ===============================
  static Future<void> updateQuestionAudioPath(
      int id, String path) async {
    final db = await database;

    await db.update(
      "questions",
      {"question_audio_path": path},
      where: "id = ?",
      whereArgs: [id],
    );
  }

  // ===============================
  // 🔹 تحديث مسار صورة السؤال
  // ===============================
  static Future<void> updateQuestionImagePath(
      int id, String path) async {
    final db = await database;

    await db.update(
      "questions",
      {"image_path": path},
      where: "id = ?",
      whereArgs: [id],
    );
  }

  // ===============================
  // 🔹 جلب كل الأسئلة
  // ===============================
  static Future<List<Map<String, dynamic>>> getAllQuestions() async {
    final db = await database;

    return await db.query(
      "questions",
      orderBy: "id DESC",
    );
  }

  // ===============================
  // 🔹 جلب غير المجابة
  // ===============================
  static Future<List<Map<String, dynamic>>> getUnanswered() async {
    final db = await database;

    return await db.query(
      "questions",
      where: "status = ?",
      whereArgs: [0],
      orderBy: "id DESC",
    );
  }

  // ===============================
  // 🔹 جلب المجابة
  // ===============================
  static Future<List<Map<String, dynamic>>> getAnswered() async {
    final db = await database;

    return await db.query(
      "questions",
      where: "status = ?",
      whereArgs: [1],
      orderBy: "id DESC",
    );
  }

  // ===============================
  // 🔹 حذف سؤال
  // ===============================
  static Future<void> deleteQuestion(int id) async {
    final db = await database;

    await db.delete(
      "questions",
      where: "id = ?",
      whereArgs: [id],
    );
  }

  // ===============================
  // 🔹 حذف كل البيانات
  // ===============================
  static Future<void> clearDatabase() async {
    final db = await database;
    await db.delete("questions");
  }
}