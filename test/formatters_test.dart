import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:study_planner/utils/formatters.dart';
import 'package:study_planner/widgets/common.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ar'));

  test('Egyptian counting', () {
    expect(daysText(1), 'يوم');
    expect(daysText(2), 'يومين');
    expect(daysText(5), '5 أيام');
    expect(daysText(14), '14 يوم');
  });

  test('durations', () {
    expect(durationText(const Duration(minutes: 15)), 'ربع ساعة');
    expect(durationText(const Duration(minutes: 30)), 'نص ساعة');
    expect(durationText(const Duration(minutes: 10)), '10 دقايق');
    expect(durationText(const Duration(minutes: 60)), 'ساعة');
    expect(durationText(const Duration(minutes: 90)), 'ساعة ونص');
    expect(durationText(const Duration(minutes: 80)), 'ساعة و20 دقيقة');
    expect(durationText(const Duration(hours: 5, minutes: 10)), '5 ساعات');
    expect(durationText(const Duration(days: 1)), 'يوم');
    expect(durationText(const Duration(days: 7)), 'أسبوع');
    expect(durationText(const Duration(days: 3)), '3 أيام');
  });

  test('times', () {
    expect(formatMinuteOfDay(0), '12:00\u00A0ص');
    expect(formatMinuteOfDay(9 * 60 + 5), '9:05\u00A0ص');
    expect(formatMinuteOfDay(12 * 60), '12:00\u00A0م');
    expect(formatMinuteOfDay(14 * 60 + 30), '2:30\u00A0م');
  });

  test('countdowns and friendly days', () {
    final now = DateTime(2026, 9, 28, 10);
    expect(countdownText(DateTime(2026, 9, 30, 10), now), 'باقي يومين');
    expect(countdownText(DateTime(2026, 9, 28, 8), now), 'متأخر ساعتين');
    expect(countdownText(now, now), 'دلوقتي');
    expect(friendlyDay(DateTime(2026, 9, 28, 23), now), 'النهارده');
    expect(friendlyDay(DateTime(2026, 9, 29), now), 'بكرة');
    expect(friendlyDay(DateTime(2026, 9, 27), now), 'امبارح');
    expect(friendlyDay(DateTime(2026, 10, 1), now), 'الخميس');
    expect(formatLongDate(now), 'الاثنين 28 سبتمبر');
    expect(latinDigits('٢٨ سبتمبر ١٠'), '28 سبتمبر 10');
  });

  test('numbers', () {
    expect(formatNumber(12), '12');
    expect(formatNumber(12.5), '12.5');
    expect(formatNumber(12.25), '12.25');
    expect(parseNumber('٨٫٥'), 8.5);
    expect(parseNumber('8,5'), 8.5);
    expect(parseNumber(' 10 '), 10);
    expect(parseNumber('abc'), isNull);
    expect(reminderSentence(60), 'قبلها بساعة');
    expect(reminderSentence(10), 'قبلها بـ 10 دقايق');
  });
}
