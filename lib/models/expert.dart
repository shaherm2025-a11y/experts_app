class Expert {
  final int? id;
  final String name;
  final String email;
  final String password;
  final String jobTitle;
  final int isAdmin;
  final int canViewAll; // ✅ تمت الإضافة

  Expert({
    this.id,
    required this.name,
    required this.email,
    required this.password,
    required this.jobTitle,
    this.isAdmin = 0,
    this.canViewAll = 0, // ✅ الافتراضي صفر
  });

  factory Expert.fromJson(Map<String, dynamic> json) {
    return Expert(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      password: json['password'] ?? '',
      jobTitle: json['job_title'] ?? '',
      isAdmin: json['is_admin'] ?? 0,
      canViewAll: json['can_view_all'] ?? 0, // ✅ تمت الإضافة
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'password': password,
      'job_title': jobTitle,
      'is_admin': isAdmin,
      'can_view_all': canViewAll, // ✅ تمت الإضافة
    };
  }
}
