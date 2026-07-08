class UserModel {
  final int userId;
  final String uuid;
  final String name;
  final String email;
  final String? photoUrl;
  final String? role;

  const UserModel({
    required this.userId,
    required this.uuid,
    required this.name,
    required this.email,
    this.photoUrl,
    this.role,
  });

  factory UserModel.fromJson(Map<String, dynamic> j) => UserModel(
    userId:   _asInt(j['user_id']),
    uuid:     j['uuid'] ?? '',
    name:     j['name'] ?? j['display_name'] ?? '',
    email:    j['email'] ?? '',
    photoUrl: j['photo_url'],
    role:     j['role'],
  );

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}

/// The API's MySQLi driver sometimes returns numeric columns as strings
/// (a known shared-hosting quirk when mysqlnd isn't compiled in), so
/// numeric fields must tolerate both JSON numbers and numeric strings.
int _asInt(dynamic v) => v is num ? v.toInt() : int.parse(v.toString());
