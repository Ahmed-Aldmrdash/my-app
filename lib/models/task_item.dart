import '../utils/json.dart';

enum Priority { low, medium, high }

/// A personal to-do (تاسك).
class TaskItem {
  const TaskItem({
    required this.id,
    required this.title,
    this.notes = '',
    this.subjectId,
    this.dueDate,
    this.priority = Priority.medium,
    this.done = false,
    this.completedAt,
    this.reminders = const [60],
  });

  final String id;
  final String title;
  final String notes;
  final String? subjectId;
  final DateTime? dueDate;
  final Priority priority;
  final bool done;
  final DateTime? completedAt;

  /// Minutes before [dueDate] to remind.
  final List<int> reminders;

  bool isOverdue(DateTime now) =>
      !done && dueDate != null && dueDate!.isBefore(now);

  TaskItem toggled() => TaskItem(
    id: id,
    title: title,
    notes: notes,
    subjectId: subjectId,
    dueDate: dueDate,
    priority: priority,
    done: !done,
    completedAt: done ? null : DateTime.now(),
    reminders: reminders,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'notes': notes,
    'subjectId': subjectId,
    'dueDate': writeDate(dueDate),
    'priority': priority.name,
    'done': done,
    'completedAt': writeDate(completedAt),
    'reminders': reminders,
  };

  factory TaskItem.fromJson(Map<String, dynamic> j) => TaskItem(
    id: readString(j['id']),
    title: readString(j['title']),
    notes: readString(j['notes']),
    subjectId: readNullableString(j['subjectId']),
    dueDate: readDate(j['dueDate']),
    priority: enumByName(Priority.values, j['priority'], Priority.medium),
    done: readBool(j['done']),
    completedAt: readDate(j['completedAt']),
    reminders: readIntList(j['reminders'], const [60]),
  );
}
