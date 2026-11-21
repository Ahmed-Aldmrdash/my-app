import '../utils/json.dart';

enum NoteKind { note, link }

/// A note or a link (Drive, YouTube, PDF…) kept for a subject or a lecture.
class Note {
  const Note({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.kind = NoteKind.note,
    this.subjectId,
    this.studyItemId,
    this.body = '',
    this.url = '',
    this.pinned = false,
  });

  final String id;
  final NoteKind kind;
  final String? subjectId;

  /// The lecture it belongs to, if any.
  final String? studyItemId;
  final String title;

  /// The note's text, or a description for a link.
  final String body;
  final String url;
  final bool pinned;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isLink => kind == NoteKind.link && url.isNotEmpty;

  Note copyWith({
    bool? pinned,
    String? subjectId,
    bool clearSubject = false,
    bool clearStudyItem = false,
    DateTime? updatedAt,
  }) => Note(
    id: id,
    kind: kind,
    subjectId: clearSubject ? null : (subjectId ?? this.subjectId),
    studyItemId: clearStudyItem || clearSubject ? null : studyItemId,
    title: title,
    body: body,
    url: url,
    pinned: pinned ?? this.pinned,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'subjectId': subjectId,
    'studyItemId': studyItemId,
    'title': title,
    'body': body,
    'url': url,
    'pinned': pinned,
    'createdAt': writeDate(createdAt),
    'updatedAt': writeDate(updatedAt),
  };

  factory Note.fromJson(Map<String, dynamic> j) {
    final created = readDate(j['createdAt']) ?? DateTime.now();
    return Note(
      id: readString(j['id']),
      kind: enumByName(NoteKind.values, j['kind'], NoteKind.note),
      subjectId: readNullableString(j['subjectId']),
      studyItemId: readNullableString(j['studyItemId']),
      title: readString(j['title']),
      body: readString(j['body']),
      url: readString(j['url']),
      pinned: readBool(j['pinned']),
      createdAt: created,
      updatedAt: readDate(j['updatedAt']) ?? created,
    );
  }
}

/// What kind of page a link points to, for its icon.
enum LinkType { youtube, drive, pdf, web }

LinkType linkTypeOf(String url) {
  final u = url.toLowerCase();
  if (u.contains('youtube.com') || u.contains('youtu.be')) {
    return LinkType.youtube;
  }
  if (u.contains('drive.google') || u.contains('docs.google')) {
    return LinkType.drive;
  }
  final path = Uri.tryParse(u)?.path ?? u;
  if (path.endsWith('.pdf')) return LinkType.pdf;
  return LinkType.web;
}

/// Adds https:// when the student typed just "drive.google.com/…".
String normalizeUrl(String input) {
  final t = input.trim();
  if (t.isEmpty) return t;
  // Already a link: "https://…", or "tel:" / "mailto:" without slashes.
  if (t.contains('://') ||
      RegExp(r'^(mailto|tel|sms):', caseSensitive: false).hasMatch(t)) {
    return t;
  }
  return 'https://$t';
}
