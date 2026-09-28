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
  };

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
  );
}
