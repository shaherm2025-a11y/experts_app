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
      version: 3,
      onCreate: _createDB,
	onUpgrade: (db, oldVersion, newVersion) async {

    if (oldVersion < 2) {
      await db.execute(
        "ALTER TABLE questions ADD COLUMN parent_question_id INTEGER"
      );
    }

  if (oldVersion < 3) {

    await db.execute('''
      CREATE TABLE answer_images(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        question_id INTEGER,
        image_path TEXT
      )
    ''');

  }
}
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
	  parent_question_id INTEGER,
      expert_name TEXT,
      image_path TEXT,
      question_audio_path TEXT,
      answer_audio_path TEXT,
      status INTEGER,
      question_date TEXT,
      diagnosis_date TEXT,
      created_at TEXT,
	  expert_id INTEGER,
	  has_image INTEGER,
	  question_has_audio INTEGER,
	  answer_has_audio INTEGER,
	  answer_has_image INTEGER,
	  is_synced INTEGER DEFAULT 1
    )
  ''');
  await db.execute('''
   CREATE TABLE answer_images(
   id INTEGER PRIMARY KEY AUTOINCREMENT,
   question_id INTEGER,
   image_path TEXT
  )
  ''');
  
  }
static Future<void> insertAnswerImage(
    int questionId,
    String path,
) async {

  final db = await database;

  await db.insert(
    "answer_images",
    {
      "question_id": questionId,
      "image_path": path,
    },
  );
}

static Future<List<String>> getAnswerImages(
    int questionId,
) async {

  final db = await database;

  final result = await db.query(
    "answer_images",
    where: "question_id=?",
    whereArgs: [questionId],
  );

  return result
      .map((e) => e["image_path"] as String)
      .toList();
}

static Future<void> clearAnswerImages(
    int questionId,
) async {

  final db = await database;

  await db.delete(
    "answer_images",
    where: "question_id=?",
    whereArgs: [questionId],
  );
}
  
static Future<void> insertOrUpdateQuestion(
    Map<String, dynamic> data) async {

  final db = await database;

  final existing = await db.query(
    "questions",
    where: "id = ?",
    whereArgs: [data["id"]],
  );

  if (existing.isEmpty) {

    // ? ����� ����
    await db.insert(
      "questions",
      {
        "id": data["id"],
        "question": data["question"],
        "answer": data["answer"],
		"parent_question_id": data["parent_question_id"],
        "expert_name": data["expert_name"],
        "status": data["status"] ?? 0,
        "question_date": data["question_date"],
        "diagnosis_date": data["diagnosis_date"],
        "created_at": DateTime.now().toIso8601String(),
      },
    );

  } else {

    // ? ����� ���� ��� ��������
    await db.update(
      "questions",
      {
        "question": data["question"],
        "answer": data["answer"],
		"parent_question_id": data["parent_question_id"],
        "expert_name": data["expert_name"],
        "status": data["status"] ?? 0,
        "question_date": data["question_date"],
        "diagnosis_date": data["diagnosis_date"],
      },
      where: "id = ?",
      whereArgs: [data["id"]],
    );
  }
}
  
  // ===============================
  // 🔹 تحديث الرد (نص + صوت)
  // ===============================
  static Future<void> updateAnswer1(
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

 // ������� 
 static Future<void> updateAnswer(
  int id,
  String answer,
  String? audioPath,
  int expertId,   // ? ��� ���
  {int isSynced = 0}
) async {
  final db = await database;

  await db.update(
    "questions",
    {
      "answer": answer,
      "answer_audio_path": audioPath,
      "status": 1,
      "expert_id": expertId,   // ? ��� ����
      "is_synced": isSynced,
      "diagnosis_date": DateTime.now().toIso8601String(),
    },
    where: "id = ?",
    whereArgs: [id],
  );
}
  
  static Future<List<Map<String, dynamic>>> getUnsyncedAnswers() async {
  final db = await database;

  return await db.query(
    "questions",
    where: "status = ? AND is_synced = ?",
    whereArgs: [1, 0],
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
  static Future<List<Map<String, dynamic>>> getAllQuestions({
  int limit = 20,
  int offset = 0,
   }) async {
  final db = await database;

   return await db.query(
    "questions",
    orderBy: "id DESC",
    limit: limit,
    offset: offset,
   );
 }
  // ===============================
  // 🔹 جلب غير المجابة
  // ===============================
  static Future<List<Map<String, dynamic>>> getUnanswered({
  int limit = 20,
  int offset = 0,
}) async {
  final db = await database;

  return await db.query(
    "questions",
    where: "status = ?",
    whereArgs: [0],
    orderBy: "id DESC",
    limit: limit,
    offset: offset,
  );
}
  // ===============================
  // 🔹 جلب المجابة
  // ===============================
  static Future<List<Map<String, dynamic>>> getAnswered({
   int limit = 20,
   int offset = 0,
   }) async {
  final db = await database;

   return await db.query(
    "questions",
    where: "status = ?",
    whereArgs: [1],
    orderBy: "id DESC",
    limit: limit,
    offset: offset,
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
  
  static Future<void> updateAnswerAudioPath(
  int id,
  String audioPath,
) async {
  final db = await database;

  await db.update(
    "questions",
    {
      "answer_audio_path": audioPath,
    },
    where: "id = ?",
    whereArgs: [id],
  );
}

static Future<void> updateAnswerImagePath(int id, String path) async {
  final db = await database;

  await db.update(
    'questions',
    {"answer_image_path": path},
    where: "id = ?",
    whereArgs: [id],
  );
}
}

