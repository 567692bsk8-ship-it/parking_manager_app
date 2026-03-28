class AuthUser {
  final String uid;
  final String email;
  final String role; // 'admin', 'dev', 'user'
  final String? displayName;
  final String? photoUrl;
  final String? managerCode; // 6-digit short code for QR fallback
  final bool isGuest;

  AuthUser({
    required this.uid,
    required this.email,
    required this.role,
    this.displayName,
    this.photoUrl,
    this.managerCode,
    this.isGuest = false,
  });

  factory AuthUser.fromMap(Map<String, dynamic> map, String uid) {
    return AuthUser(
      uid: uid,
      email: map['email'] ?? '',
      role: map['role'] ?? 'user',
      displayName: map['display_name'],
      photoUrl: map['photo_url'],
      managerCode: map['manager_code'],
      isGuest: map['is_guest'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'role': role,
      'display_name': displayName,
      'photo_url': photoUrl,
      'manager_code': managerCode,
      'is_guest': isGuest,
      'updated_at': DateTime.now(),
    };
  }
}
