enum NoteType { text, checklist, voice, image }

class Note {
  final int? id;
  final String title;
  final String content;
  final NoteType type;
  final String? category;
  final int color;
  final bool isPinned;
  final bool isArchived;
  final bool isTrashed;
  final DateTime? reminderTime;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  Note({
    this.id,
    required this.title,
    required this.content,
    this.type = NoteType.text,
    this.category,
    this.color = 0xFFFFFFFF,
    this.isPinned = false,
    this.isArchived = false,
    this.isTrashed = false,
    this.reminderTime,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  Note copyWith({
    int? id,
    String? title,
    String? content,
    NoteType? type,
    String? category,
    int? color,
    bool? isPinned,
    bool? isArchived,
    bool? isTrashed,
    DateTime? reminderTime,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      type: type ?? this.type,
      category: category ?? this.category,
      color: color ?? this.color,
      isPinned: isPinned ?? this.isPinned,
      isArchived: isArchived ?? this.isArchived,
      isTrashed: isTrashed ?? this.isTrashed,
      reminderTime: reminderTime ?? this.reminderTime,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'type': type.index,
      'category': category,
      'color': color,
      'isPinned': isPinned ? 1 : 0,
      'isArchived': isArchived ? 1 : 0,
      'isTrashed': isTrashed ? 1 : 0,
      'reminderTime': reminderTime?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'deletedAt': deletedAt?.toIso8601String(),
    };
  }

  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'],
      title: map['title'],
      content: map['content'],
      type: NoteType.values[map['type']],
      category: map['category'],
      color: map['color'],
      isPinned: map['isPinned'] == 1,
      isArchived: map['isArchived'] == 1,
      isTrashed: map['isTrashed'] == 1,
      reminderTime: map['reminderTime'] != null ? DateTime.parse(map['reminderTime']) : null,
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
      deletedAt: map['deletedAt'] != null ? DateTime.parse(map['deletedAt']) : null,
    );
  }
}
