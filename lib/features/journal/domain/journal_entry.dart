/// Pure data class for a journal entry. Stored in SharedPreferences as
/// JSON via [toJson]/[fromJson] and serialized to Appwrite as the
/// `content` field of `journal_entries`.
class JournalEntry {
  final String id;
  final DateTime createdAt;
  final String content;

  const JournalEntry({
    required this.id,
    required this.createdAt,
    required this.content,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'created_at': createdAt.toIso8601String(),
        'content': content,
      };

  factory JournalEntry.fromJson(Map<String, dynamic> json) => JournalEntry(
        id: json['id'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        content: json['content'] as String,
      );
}