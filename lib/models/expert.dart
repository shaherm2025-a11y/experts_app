
class Expert {
  final int? id;
  final String name;
  final String email;
  final String password;
  final String jobTitle;
  final int isAdmin;
  final int canViewAll;

  Expert({
    this.id,
    required this.name,
    required this.email,
    required this.password,
    required this.jobTitle,
    this.isAdmin = 0,
    this.canViewAll = 0,
  });

  // تحويل القيم القادمة من API إلى int بأمان
  static int _parseInt(dynamic value) {
    if (value == null) return 0;

    if (value is int) return value;

    if (value is bool) {
      return value ? 1 : 0;
    }

    if (value is num) {
      return value.toInt();
    }

    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;

      if (value.toLowerCase() == 'true') return 1;
      if (value.toLowerCase() == 'false') return 0;
    }

    return 0;
  }

  factory Expert.fromJson(Map<String, dynamic> json) {
    return Expert(
      id: json['id'] == null
          ? null
          : _parseInt(json['id']),
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      password: json['password']?.toString() ?? '',
      jobTitle: json['job_title']?.toString() ?? '',
      isAdmin: _parseInt(json['is_admin']),
      canViewAll: _parseInt(json['can_view_all']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'password': password,
      'job_title': jobTitle,
      'is_admin': isAdmin,
      'can_view_all': canViewAll,
    };
  }
}
