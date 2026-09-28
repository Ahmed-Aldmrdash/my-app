import 'package:intl/intl.dart';

/// Arabic weekday names keyed by [DateTime.weekday].
const weekdayNames = <int, String>{
  DateTime.saturday: 'السبت',
  DateTime.sunday: 'الأحد',
  DateTime.monday: 'الاثنين',
  DateTime.tuesday: 'الثلاثاء',
  DateTime.wednesday: 'الأربعاء',
  DateTime.thursday: 'الخميس',
  DateTime.friday: 'الجمعة',
};

/// Short Egyptian day names for tight spaces (charts, chips).
const weekdayShortNames = <int, String>{
  DateTime.saturday: 'سبت',
  DateTime.sunday: 'حد',
  DateTime.monday: 'اتنين',
  DateTime.tuesday: 'تلات',
  DateTime.wednesday: 'أربع',
  DateTime.thursday: 'خميس',
  DateTime.friday: 'جمعة',
};

/// The university week, Saturday first.
const weekOrder = <int>[
  DateTime.saturday,
  DateTime.sunday,
  DateTime.monday,
  DateTime.tuesday,
  DateTime.wednesday,
  DateTime.thursday,
  DateTime.friday,
];

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Egyptian-Arabic counting: "يوم"، "يومين"، "3 أيام"، "11 يوم".
String countText(int n, String one, String two, String few, String many) {
  if (n == 1) return one;
  if (n == 2) return two;
  if (n >= 3 && n <= 10) return '$n $few';
  return '$n $many';
}

String minutesText(int n) => countText(n, 'دقيقة', 'دقيقتين', 'دقايق', 'دقيقة');
String hoursText(int n) => countText(n, 'ساعة', 'ساعتين', 'ساعات', 'ساعة');
String daysText(int n) => countText(n, 'يوم', 'يومين', 'أيام', 'يوم');

/// "9:30 ص" / "2:00 م" from minutes since midnight.
String formatMinuteOfDay(int minuteOfDay) {
  final h = minuteOfDay ~/ 60;
  final m = minuteOfDay % 60;
  final period = h < 12 ? 'ص' : 'م';
  final h12 = h % 12 == 0 ? 12 : h % 12;
  // Non-breaking space so "10:00 ص" never wraps apart.
  return '$h12:${m.toString().padLeft(2, '0')}\u00A0$period';
}

String formatTime(DateTime d) => formatMinuteOfDay(d.hour * 60 + d.minute);

/// Depending on how the locale data was loaded, Arabic dates may come out
/// with Arabic-Indic digits; keep every number in the app in one style.
String latinDigits(String s) => s.replaceAllMapped(
  RegExp('[٠-٩]'),
  (m) => (m[0]!.codeUnitAt(0) - 0x0660).toString(),
);

/// "الاثنين 28 سبتمبر"
String formatLongDate(DateTime d) =>
    latinDigits(DateFormat('EEEE d MMMM', 'ar').format(d));

/// "28 سبتمبر"
String formatShortDate(DateTime d) =>
    latinDigits(DateFormat('d MMMM', 'ar').format(d));

/// "النهارده" / "بكرة" / "امبارح" / weekday within a week / a date.
String friendlyDay(DateTime d, DateTime now) {
  final diff = dateOnly(d).difference(dateOnly(now)).inDays;
  if (diff == 0) return 'النهارده';
  if (diff == 1) return 'بكرة';
  if (diff == -1) return 'امبارح';
  if (diff > 1 && diff < 7) return weekdayNames[d.weekday]!;
  return formatShortDate(d);
}

String friendlyDateTime(DateTime d, DateTime now) =>
    '${friendlyDay(d, now)} • ${formatTime(d)}';

/// "ساعتين"، "3 أيام"، "ربع ساعة"…
String durationText(Duration d) {
  final minutes = d.inMinutes.abs();
  if (minutes < 60) {
    if (minutes == 15) return 'ربع ساعة';
    if (minutes == 30) return 'نص ساعة';
    return minutesText(minutes);
  }
  final hours = minutes ~/ 60;
  if (hours < 24) {
    final rest = minutes % 60;
    if (rest == 30) return '${hoursText(hours)} ونص';
    if (rest == 0 || hours >= 3) return hoursText(hours);
    return '${hoursText(hours)} و${minutesText(rest)}';
  }
  final days = hours ~/ 24;
  if (days % 7 == 0 && days <= 28) {
    final weeks = days ~/ 7;
    return countText(weeks, 'أسبوع', 'أسبوعين', 'أسابيع', 'أسبوع');
  }
  return daysText(days);
}

/// "باقي 3 أيام" / "متأخر ساعتين" / "دلوقتي".
String countdownText(DateTime target, DateTime now) {
  final diff = target.difference(now);
  if (diff.inMinutes.abs() < 1) return 'دلوقتي';
  return diff.isNegative
      ? 'متأخر ${durationText(diff)}'
      : 'باقي ${durationText(diff)}';
}

/// Short label for a "remind me X before" option, e.g. "ساعة", "يوم".
String reminderText(int minutesBefore) {
  if (minutesBefore <= 0) return 'في وقتها';
  return durationText(Duration(minutes: minutesBefore));
}

/// "قبلها بساعة" / "قبلها بـ 10 دقايق" / "في وقتها".
String reminderSentence(int minutesBefore) {
  if (minutesBefore <= 0) return 'في وقتها';
  final text = durationText(Duration(minutes: minutesBefore));
  final startsWithDigit = RegExp(r'^\d').hasMatch(text);
  return startsWithDigit ? 'قبلها بـ $text' : 'قبلها ب$text';
}

/// 12 -> "12", 12.5 -> "12.5", 12.25 -> "12.25"
String formatNumber(double v) {
  if (v == v.roundToDouble()) return v.toInt().toString();
  var s = v.toStringAsFixed(2);
  s = s.replaceFirst(RegExp(r'0+$'), '');
  return s.endsWith('.') ? s.substring(0, s.length - 1) : s;
}

/// Keeps numbers like "8.5/10" or "+2" in left-to-right order inside
/// Arabic text (Unicode left-to-right isolate).
String ltr(String s) => '\u2066$s\u2069';

/// "8.5/10", always displayed in that order.
String fraction(double score, double max) =>
    ltr('${formatNumber(score)}/${formatNumber(max)}');

String formatPercent(double? p) => p == null ? '—' : '${p.round()}%';
