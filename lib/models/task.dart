enum TaskPriority { low, medium, high }
enum TaskStatus { pending, inProgress, completed }
enum RecurringInterval { none, daily, weekly, monthly }

class Task {
  final int? id;
  final String title;
  final String description;
  final DateTime? startTime;
  final DateTime? expiryTime;
  final TaskPriority priority;
  final TaskStatus status;
  final bool isRecurring;
  final RecurringInterval recurringInterval;
  final DateTime createdAt;
  final DateTime updatedAt;

  Task({
    this.id,
    required this.title,
    this.description = '',
    this.startTime,
    this.expiryTime,
    this.priority = TaskPriority.low,
    this.status = TaskStatus.pending,
    this.isRecurring = false,
    this.recurringInterval = RecurringInterval.none,
    required this.createdAt,
    required this.updatedAt,
  });

  Task copyWith({
    int? id,
    String? title,
    String? description,
    DateTime? startTime,
    DateTime? expiryTime,
    TaskPriority? priority,
    TaskStatus? status,
    bool? isRecurring,
    RecurringInterval? recurringInterval,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      startTime: startTime ?? this.startTime,
      expiryTime: expiryTime ?? this.expiryTime,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      isRecurring: isRecurring ?? this.isRecurring,
      recurringInterval: recurringInterval ?? this.recurringInterval,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'startTime': startTime?.toIso8601String(),
      'expiryTime': expiryTime?.toIso8601String(),
      'priority': priority.index,
      'status': status.index,
      'isRecurring': isRecurring ? 1 : 0,
      'recurringInterval': recurringInterval.index,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'],
      title: map['title'],
      description: map['description'] ?? '',
      startTime: map['startTime'] != null ? DateTime.parse(map['startTime']) : null,
      expiryTime: map['expiryTime'] != null ? DateTime.parse(map['expiryTime']) : null,
      priority: TaskPriority.values[map['priority']],
      status: TaskStatus.values[map['status']],
      isRecurring: map['isRecurring'] == 1,
      recurringInterval: RecurringInterval.values[map['recurringInterval']],
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
    );
  }
}
