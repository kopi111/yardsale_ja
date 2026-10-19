class User {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String parish;
  final String? avatarPath;
  final bool isCurrent;
  final bool isDemo;
  final DateTime createdAt;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.parish,
    this.avatarPath,
    this.isCurrent = false,
    this.isDemo = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'parish': parish,
        'avatar_path': avatarPath,
        'is_current': isCurrent ? 1 : 0,
        'is_demo': isDemo ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
      };

  factory User.fromMap(Map<String, dynamic> map) => User(
        id: map['id'],
        name: map['name'],
        email: map['email'] ?? '',
        phone: map['phone'] ?? '',
        parish: map['parish'] ?? '',
        avatarPath: map['avatar_path'],
        isCurrent: map['is_current'] == 1,
        isDemo: map['is_demo'] == 1,
        createdAt: DateTime.parse(map['created_at']),
      );

  User copyWith({
    String? name,
    String? email,
    String? phone,
    String? parish,
    String? avatarPath,
    bool? isCurrent,
  }) =>
      User(
        id: id,
        name: name ?? this.name,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        parish: parish ?? this.parish,
        avatarPath: avatarPath ?? this.avatarPath,
        isCurrent: isCurrent ?? this.isCurrent,
        isDemo: isDemo,
        createdAt: createdAt,
      );
}
