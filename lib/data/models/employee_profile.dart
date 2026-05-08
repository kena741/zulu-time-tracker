/// Row from `public.employees` (linked to `auth.users`).
class EmployeeProfile {
  EmployeeProfile({
    required this.id,
    required this.userId,
    required this.firstName,
    required this.lastName,
    this.phone,
    required this.email,
    required this.createdAt,
  });

  factory EmployeeProfile.fromJson(Map<String, dynamic> json) {
    return EmployeeProfile(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
      phone: json['phone'] as String?,
      email: json['email'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final String id;
  final String userId;
  final String firstName;
  final String lastName;
  final String? phone;
  final String email;
  final DateTime createdAt;

  String get fullName => '$firstName $lastName'.trim();
}
