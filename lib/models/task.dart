import 'recurring_interval.dart';

enum TaskPriority { low, medium, high }
enum NoteTaskStatus { pending, inProgress, completed }

class Task {
  final int? id;
  final String title;
  final String description;
  final DateTime? reminderTime;
  final TaskPriority priority;
  final NoteTaskStatus status;
  final bool isRecurring;
  final RecurringInterval recurringInterval;
  final int? customIntervalValue;
  final CustomIntervalUnit? customIntervalUnit;
  final DateTime createdAt;
  final DateTime updatedAt;

  Task({
    this.id,
    required this.title,
    this.description = '',
    this.reminderTime,
    this.priority = TaskPriority.low,
    this.status = NoteTaskStatus.pending,
    this.isRecurring = false,
    this.recurringInterval = RecurringInterval.none,
    this.customIntervalValue,
    this.customIntervalUnit,
    required this.createdAt,
    required this.updatedAt,
  });

  Task copyWith({
    int? id,
    String? title,
    String? description,
    DateTime? reminderTime,
    TaskPriority? priority,
    NoteTaskStatus? status,
    bool? isRecurring,
    RecurringInterval? recurringInterval,
    int? customIntervalValue,
    CustomIntervalUnit? customIntervalUnit,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      reminderTime: reminderTime ?? this.reminderTime,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      isRecurring: isRecurring ?? this.isRecurring,
      recurringInterval: recurringInterval ?? this.recurringInterval,
      customIntervalValue: customIntervalValue ?? this.customIntervalValue,
      customIntervalUnit: customIntervalUnit ?? this.customIntervalUnit,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'reminderTime': reminderTime?.toIso8601String(),
      'priority': priority.index,
      'status': status.index,
      'isRecurring': isRecurring ? 1 : 0,
      'recurringInterval': recurringInterval.index,
      'customIntervalValue': customIntervalValue,
      'customIntervalUnit': customIntervalUnit?.index,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'],
      title: map['title'],
      description: map['description'] ?? '',
      reminderTime: map['reminderTime'] != null ? DateTime.parse(map['reminderTime']) : null,
      priority: TaskPriority.values[map['priority']],
      status: NoteTaskStatus.values[map['status']],
      isRecurring: map['isRecurring'] == 1,
      recurringInterval: RecurringInterval.values[map['recurringInterval'] ?? 0],
      customIntervalValue: map['customIntervalValue'],
      customIntervalUnit: map['customIntervalUnit'] != null ? CustomIntervalUnit.values[map['customIntervalUnit']] : null,
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
    );
  }
}
