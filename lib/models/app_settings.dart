import '../utils/json.dart';

enum AppThemeMode { system, light, dark }

/// How marks are turned into a grade.
enum GradingSystem {
  /// ممتاز / جيد جداً / جيد / مقبول
  percentage,

  /// Credit-hour system with letter grades and a GPA.
  gpa,
}

class AppSettings {
  const AppSettings({
    this.studentName = '',
    this.notificationsEnabled = true,
    this.defaultClassReminder = 15,
    this.dailySummaryEnabled = true,
    this.dailySummaryMinute = 8 * 60,
    this.themeMode = AppThemeMode.system,
    this.askedPermissions = false,
    this.gradingSystem = GradingSystem.percentage,
    this.dailyGoalMinutes = 120,
    this.focusMinutes = 25,
    this.breakMinutes = 5,
    this.planPerDay = 4,
    this.semesterName = '',
    this.graduationHours = 0,
  });

  final String studentName;
  final bool notificationsEnabled;

  /// Default minutes-before for new timetable slots.
  final int defaultClassReminder;

  /// A morning notification summarising the day.
  final bool dailySummaryEnabled;

  /// Minutes since midnight.
  final int dailySummaryMinute;
  final AppThemeMode themeMode;

  /// Whether the first-launch permission prompt was already shown.
  final bool askedPermissions;
  final GradingSystem gradingSystem;

  /// Target study time per day, in minutes.
  final int dailyGoalMinutes;

  /// Default focus and break lengths for the timer.
  final int focusMinutes;
  final int breakMinutes;

  /// How many entries the finals study planner puts on each day.
  final int planPerDay;

  /// The current semester's name, e.g. "الترم التاني 2025/2026".
  final String semesterName;

  /// Credit hours needed to graduate; 0 when not set.
  final int graduationHours;

  AppSettings copyWith({
    String? studentName,
    bool? notificationsEnabled,
    int? defaultClassReminder,
    bool? dailySummaryEnabled,
    int? dailySummaryMinute,
    AppThemeMode? themeMode,
    bool? askedPermissions,
    GradingSystem? gradingSystem,
    int? dailyGoalMinutes,
    int? focusMinutes,
    int? breakMinutes,
    int? planPerDay,
    String? semesterName,
    int? graduationHours,
  }) => AppSettings(
    studentName: studentName ?? this.studentName,
    notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    defaultClassReminder: defaultClassReminder ?? this.defaultClassReminder,
    dailySummaryEnabled: dailySummaryEnabled ?? this.dailySummaryEnabled,
    dailySummaryMinute: dailySummaryMinute ?? this.dailySummaryMinute,
    themeMode: themeMode ?? this.themeMode,
    askedPermissions: askedPermissions ?? this.askedPermissions,
    gradingSystem: gradingSystem ?? this.gradingSystem,
    dailyGoalMinutes: dailyGoalMinutes ?? this.dailyGoalMinutes,
    focusMinutes: focusMinutes ?? this.focusMinutes,
    breakMinutes: breakMinutes ?? this.breakMinutes,
    planPerDay: planPerDay ?? this.planPerDay,
    semesterName: semesterName ?? this.semesterName,
    graduationHours: graduationHours ?? this.graduationHours,
  );

  Map<String, dynamic> toJson() => {
    'studentName': studentName,
    'notificationsEnabled': notificationsEnabled,
    'defaultClassReminder': defaultClassReminder,
    'dailySummaryEnabled': dailySummaryEnabled,
    'dailySummaryMinute': dailySummaryMinute,
    'themeMode': themeMode.name,
    'askedPermissions': askedPermissions,
    'gradingSystem': gradingSystem.name,
    'dailyGoalMinutes': dailyGoalMinutes,
    'focusMinutes': focusMinutes,
    'breakMinutes': breakMinutes,
    'planPerDay': planPerDay,
    'semesterName': semesterName,
    'graduationHours': graduationHours,
  };

  /// Keys of [toJson] that stay on this device: the theme and whether the
  /// permission prompt was shown.
  static const localOnlyKeys = {'themeMode', 'askedPermissions'};

  /// Settings shared between devices (everything but [localOnlyKeys]).
  Map<String, dynamic> toSyncJson() =>
      toJson()..removeWhere((k, _) => localOnlyKeys.contains(k));

  /// These settings with the shared ones replaced by [synced].
  AppSettings withSynced(Map<String, dynamic> synced) => AppSettings.fromJson({
    ...synced,
    'themeMode': themeMode.name,
    'askedPermissions': askedPermissions,
  });

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
    studentName: readString(j['studentName']),
    notificationsEnabled: readBool(j['notificationsEnabled'], true),
    defaultClassReminder: readInt(j['defaultClassReminder'], 15),
    dailySummaryEnabled: readBool(j['dailySummaryEnabled'], true),
    dailySummaryMinute: readInt(j['dailySummaryMinute'], 8 * 60),
    themeMode: enumByName(
      AppThemeMode.values,
      j['themeMode'],
      AppThemeMode.system,
    ),
    askedPermissions: readBool(j['askedPermissions']),
    gradingSystem: enumByName(
      GradingSystem.values,
      j['gradingSystem'],
      GradingSystem.percentage,
    ),
    dailyGoalMinutes: readInt(j['dailyGoalMinutes'], 120).clamp(10, 16 * 60),
    focusMinutes: readInt(j['focusMinutes'], 25).clamp(1, 180),
    breakMinutes: readInt(j['breakMinutes'], 5).clamp(1, 60),
    planPerDay: readInt(j['planPerDay'], 4).clamp(1, 12),
    semesterName: readString(j['semesterName']),
    graduationHours: readInt(j['graduationHours']).clamp(0, 400),
  );
}
