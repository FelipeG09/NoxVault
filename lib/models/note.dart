/// Modelo de nota / credencial no cofre.
class Note {
  final String id;
  final String title;
  /// Texto livre (observações, 2FA backup, etc.).
  final String content;
  final String username;
  final String password;
  final DateTime createdAt;

  Note({
    required this.id,
    required this.title,
    required this.content,
    this.username = '',
    this.password = '',
    required this.createdAt,
  });

  bool get hasCredentialFields =>
      username.trim().isNotEmpty || password.trim().isNotEmpty;

  Note copyWith({
    String? id,
    String? title,
    String? content,
    String? username,
    String? password,
    DateTime? createdAt,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      username: username ?? this.username,
      password: password ?? this.password,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'username': username,
        'password': password,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Note.fromJson(Map<String, dynamic> json) => Note(
        id: json['id'] as String,
        title: json['title'] as String,
        content: json['content'] as String? ?? '',
        username: json['username'] as String? ?? '',
        password: json['password'] as String? ?? '',
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
