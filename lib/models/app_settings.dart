import '../utils/json.dart';

enum AppThemeMode { system, light, dark }

class AppSettings {
  const AppSettings({
    this.studentName = '',
    this.notificationsEnabled = true,
    this.defaultClassReminder = 15,
    this.dailySummaryEnabled = true,
    this.dailySummaryMinute = 8 * 60,
    this.themeMode = AppThemeMode.system,
    this.askedPermissions = false,
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

  AppSettings copyWith({
    String? studentName,
    bool? notificationsEnabled,
    int? defaultClassReminder,
    bool? dailySummaryEnabled,
    int? dailySummaryMinute,
    AppThemeMode? themeMode,
    bool? askedPermissions,
  }) => AppSettings(
    studentName: studentName ?? this.studentName,
    notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    defaultClassReminder: defaultClassReminder ?? this.defaultClassReminder,
    dailySummaryEnabled: dailySummaryEnabled ?? this.dailySummaryEnabled,
    dailySummaryMinute: dailySummaryMinute ?? this.dailySummaryMinute,
    themeMode: themeMode ?? this.themeMode,
    askedPermissions: askedPermissions ?? this.askedPermissions,
  );

  Map<String, dynamic> toJson() => {
    'studentName': studentName,
    'notificationsEnabled': notificationsEnabled,
    'defaultClassReminder': defaultClassReminder,
    'dailySummaryEnabled': dailySummaryEnabled,
    'dailySummaryMinute': dailySummaryMinute,
    'themeMode': themeMode.name,
    'askedPermissions': askedPermissions,
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
  );
}
