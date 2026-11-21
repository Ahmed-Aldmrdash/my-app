import '../utils/json.dart';

enum ContactRole { doctor, assistant, classmate, staff, other }

/// A weekly time someone can be found, e.g. office hours.
class WeeklySlot {
  const WeeklySlot({
    required this.weekday,
    required this.startMinute,
    required this.endMinute,
  });

  /// [DateTime.monday] … [DateTime.sunday].
  final int weekday;
  final int startMinute;
  final int endMinute;

  Map<String, dynamic> toJson() => {
    'weekday': weekday,
    'start': startMinute,
    'end': endMinute,
  };

  factory WeeklySlot.fromJson(Map<String, dynamic> j) => WeeklySlot(
    weekday: readInt(j['weekday'], DateTime.sunday).clamp(1, 7),
    startMinute: readInt(j['start'], 10 * 60).clamp(0, 24 * 60 - 1),
    endMinute: readInt(j['end'], 11 * 60).clamp(0, 24 * 60 - 1),
  );
}

/// A doctor, a teaching assistant, a classmate… with how to reach them.
class Contact {
  const Contact({
    required this.id,
    required this.name,
    this.role = ContactRole.doctor,
    this.subjectIds = const [],
    this.phone = '',
    this.email = '',
    this.office = '',
    this.officeHours = const [],
    this.notes = '',
  });

  final String id;
  final String name;
  final ContactRole role;

  /// The subjects they teach or share with the student.
  final List<String> subjectIds;
  final String phone;
  final String email;

  /// Where to find them (المكتب).
  final String office;
  final List<WeeklySlot> officeHours;
  final String notes;

  Contact withoutSubject(String subjectId) => Contact(
    id: id,
    name: name,
    role: role,
    subjectIds: [...subjectIds]..remove(subjectId),
    phone: phone,
    email: email,
    office: office,
    officeHours: officeHours,
    notes: notes,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'role': role.name,
    'subjectIds': subjectIds,
    'phone': phone,
    'email': email,
    'office': office,
    'officeHours': [for (final s in officeHours) s.toJson()],
    'notes': notes,
  };

  factory Contact.fromJson(Map<String, dynamic> j) => Contact(
    id: readString(j['id']),
    name: readString(j['name']),
    role: enumByName(ContactRole.values, j['role'], ContactRole.other),
    subjectIds: readStringList(j['subjectIds']),
    phone: readString(j['phone']),
    email: readString(j['email']),
    office: readString(j['office']),
    officeHours: readList(j['officeHours'], WeeklySlot.fromJson),
    notes: readString(j['notes']),
  );
}

/// A study group or a project team, usually with a chat link.
class StudyGroup {
  const StudyGroup({
    required this.id,
    required this.name,
    this.subjectId,
    this.memberIds = const [],
    this.link = '',
    this.notes = '',
  });

  final String id;
  final String name;
  final String? subjectId;

  /// Contacts in the group.
  final List<String> memberIds;

  /// e.g. the WhatsApp or Telegram group link.
  final String link;
  final String notes;

  StudyGroup copyWith({List<String>? memberIds, bool clearSubject = false}) =>
      StudyGroup(
        id: id,
        name: name,
        subjectId: clearSubject ? null : subjectId,
        memberIds: memberIds ?? this.memberIds,
        link: link,
        notes: notes,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'subjectId': subjectId,
    'memberIds': memberIds,
    'link': link,
    'notes': notes,
  };

  factory StudyGroup.fromJson(Map<String, dynamic> j) => StudyGroup(
    id: readString(j['id']),
    name: readString(j['name']),
    subjectId: readNullableString(j['subjectId']),
    memberIds: readStringList(j['memberIds']),
    link: readString(j['link']),
    notes: readString(j['notes']),
  );
}
