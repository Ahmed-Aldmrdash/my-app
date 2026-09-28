import '../utils/json.dart';

class ProjectStep {
  const ProjectStep({required this.id, required this.title, this.done = false});

  final String id;
  final String title;
  final bool done;

  ProjectStep copyWith({String? title, bool? done}) =>
      ProjectStep(id: id, title: title ?? this.title, done: done ?? this.done);

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'done': done};

  factory ProjectStep.fromJson(Map<String, dynamic> j) => ProjectStep(
    id: readString(j['id']),
    title: readString(j['title']),
    done: readBool(j['done']),
  );
}

/// A course or personal project, tracked through its steps (مراحل).
class Project {
  const Project({
    required this.id,
    required this.title,
    this.subjectId,
    this.description = '',
    this.team = '',
    this.deadline,
    this.steps = const [],
    this.manualProgress = 0,
    this.submitted = false,
    this.reminders = const [3 * 24 * 60, 24 * 60],
  });

  final String id;
  final String title;
  final String? subjectId;
  final String description;
  final String team;
  final DateTime? deadline;
  final List<ProjectStep> steps;

  /// 0..100, used only while the project has no steps.
  final int manualProgress;
  final bool submitted;

  /// Minutes before [deadline] to remind.
  final List<int> reminders;

  int get doneSteps => steps.where((s) => s.done).length;

  /// 0.0 .. 1.0
  double get progress {
    if (submitted) return 1;
    if (steps.isEmpty) return manualProgress.clamp(0, 100) / 100;
    return doneSteps / steps.length;
  }

  bool isOverdue(DateTime now) =>
      !submitted && deadline != null && deadline!.isBefore(now);

  Project copyWith({
    List<ProjectStep>? steps,
    int? manualProgress,
    bool? submitted,
  }) => Project(
    id: id,
    title: title,
    subjectId: subjectId,
    description: description,
    team: team,
    deadline: deadline,
    steps: steps ?? this.steps,
    manualProgress: manualProgress ?? this.manualProgress,
    submitted: submitted ?? this.submitted,
    reminders: reminders,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'subjectId': subjectId,
    'description': description,
    'team': team,
    'deadline': writeDate(deadline),
    'steps': steps.map((s) => s.toJson()).toList(),
    'manualProgress': manualProgress,
    'submitted': submitted,
    'reminders': reminders,
  };

  factory Project.fromJson(Map<String, dynamic> j) => Project(
    id: readString(j['id']),
    title: readString(j['title']),
    subjectId: readNullableString(j['subjectId']),
    description: readString(j['description']),
    team: readString(j['team']),
    deadline: readDate(j['deadline']),
    steps: readList(j['steps'], ProjectStep.fromJson),
    manualProgress: readInt(j['manualProgress']).clamp(0, 100),
    submitted: readBool(j['submitted']),
    reminders: readIntList(j['reminders'], const [3 * 24 * 60, 24 * 60]),
  );
}
