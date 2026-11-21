import '../utils/json.dart';
import 'project.dart';

enum AchievementKind {
  course,
  certificate,
  internship,
  activity,
  volunteering,
  competition,
  skill,
}

/// Something for the CV: a course, a certificate, an internship, a student
/// activity, a skill…
class Achievement {
  const Achievement({
    required this.id,
    required this.title,
    this.kind = AchievementKind.course,
    this.organization = '',
    this.start,
    this.end,
    this.ongoing = false,
    this.url = '',
    this.description = '',
  });

  final String id;
  final AchievementKind kind;
  final String title;

  /// Who gave it: the platform, company, team…
  final String organization;
  final DateTime? start;
  final DateTime? end;

  /// Still going on (no end date yet).
  final bool ongoing;

  /// A link to the certificate or the work.
  final String url;
  final String description;

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'title': title,
    'organization': organization,
    'start': writeDate(start),
    'end': writeDate(end),
    'ongoing': ongoing,
    'url': url,
    'description': description,
  };

  factory Achievement.fromJson(Map<String, dynamic> j) => Achievement(
    id: readString(j['id']),
    kind: enumByName(AchievementKind.values, j['kind'], AchievementKind.course),
    title: readString(j['title']),
    organization: readString(j['organization']),
    start: readDate(j['start']),
    end: readDate(j['end']),
    ongoing: readBool(j['ongoing']),
    url: readString(j['url']),
    description: readString(j['description']),
  );
}

enum ApplicationKind {
  scholarship,
  internship,
  job,
  competition,
  exchange,
  other,
}

enum ApplicationStatus { planning, applied, interview, accepted, rejected }

/// A scholarship, internship or competition to apply for, with its deadline
/// and what it needs.
class Application {
  const Application({
    required this.id,
    required this.title,
    this.kind = ApplicationKind.scholarship,
    this.organization = '',
    this.deadline,
    this.status = ApplicationStatus.planning,
    this.url = '',
    this.requirements = const [],
    this.notes = '',
    this.reminders = const [3 * 24 * 60, 24 * 60],
  });

  final String id;
  final ApplicationKind kind;
  final String title;
  final String organization;
  final DateTime? deadline;
  final ApplicationStatus status;
  final String url;

  /// What it needs (CV, transcript, letter…), ticked off one by one.
  final List<ProjectStep> requirements;
  final String notes;

  /// Minutes before [deadline] to remind.
  final List<int> reminders;

  /// Still to be sent.
  bool get isOpen => status == ApplicationStatus.planning;

  double get readiness => requirements.isEmpty
      ? 0
      : requirements.where((r) => r.done).length / requirements.length;

  Application copyWith({
    ApplicationStatus? status,
    List<ProjectStep>? requirements,
  }) => Application(
    id: id,
    kind: kind,
    title: title,
    organization: organization,
    deadline: deadline,
    status: status ?? this.status,
    url: url,
    requirements: requirements ?? this.requirements,
    notes: notes,
    reminders: reminders,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'title': title,
    'organization': organization,
    'deadline': writeDate(deadline),
    'status': status.name,
    'url': url,
    'requirements': [for (final r in requirements) r.toJson()],
    'notes': notes,
    'reminders': reminders,
  };

  factory Application.fromJson(Map<String, dynamic> j) => Application(
    id: readString(j['id']),
    kind: enumByName(ApplicationKind.values, j['kind'], ApplicationKind.other),
    title: readString(j['title']),
    organization: readString(j['organization']),
    deadline: readDate(j['deadline']),
    status: enumByName(
      ApplicationStatus.values,
      j['status'],
      ApplicationStatus.planning,
    ),
    url: readString(j['url']),
    requirements: readList(j['requirements'], ProjectStep.fromJson),
    notes: readString(j['notes']),
    reminders: readIntList(j['reminders'], const [3 * 24 * 60, 24 * 60]),
  );
}
