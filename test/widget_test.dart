import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:study_planner/app.dart';
import 'package:study_planner/data/app_store.dart';
import 'package:study_planner/data/storage.dart';
import 'package:study_planner/utils/formatters.dart';

/// The visible vertical list, to scroll lazily built items into view.
final _list = find
    .byWidgetPredicate((w) => w is Scrollable && w.axis == Axis.vertical)
    .first;

Future<void> _scrollTo(WidgetTester tester, Finder finder) =>
    tester.scrollUntilVisible(finder, 200, scrollable: _list);

Future<AppStore> _pumpApp(WidgetTester tester) async {
  // A typical phone screen, so layout overflows show up as failures.
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final store = AppStore(MemoryStorage());
  await store.load();
  await tester.pumpWidget(StudyPlannerApp(store: store));
  await tester.pumpAndSettle();
  return store;
}

void main() {
  setUpAll(() => initializeDateFormatting('ar'));

  testWidgets('first launch shows onboarding and loads demo data', (
    tester,
  ) async {
    final store = await _pumpApp(tester);
    expect(find.text('أهلاً بيك! 🎓'), findsOneWidget);

    await tester.tap(find.text('جرّب ببيانات تجريبية'));
    await tester.pumpAndSettle();

    expect(store.subjects, hasLength(4));
    expect(find.text('أهلاً بيك! 🎓'), findsNothing);
    expect(find.text('جدول النهارده'), findsOneWidget);
    await _scrollTo(tester, find.text('كويزات وتسليمات قريبة'));
    await _scrollTo(tester, find.text('تاسكات عليك'));
    await _scrollTo(tester, find.text('مشروع إدارة مكتبة'));
  });

  testWidgets('every tab and the subject grades page render', (tester) async {
    final store = await _pumpApp(tester);
    await tester.tap(find.text('جرّب ببيانات تجريبية'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('الجدول').last);
    await tester.pumpAndSettle();
    expect(find.text('ميعاد جديد'), findsOneWidget);

    await tester.tap(find.text('المذاكرة').last);
    await tester.pumpAndSettle();
    expect(find.text('محاضرة نزلت'), findsOneWidget);
    // Mark the first pending lecture as studied.
    final before = store.studyItems.where((s) => s.status.index >= 2).length;
    await tester.tap(find.byTooltip('اتذاكرت').first);
    await tester.pumpAndSettle();
    expect(
      store.studyItems.where((s) => s.status.index >= 2).length,
      before + 1,
    );

    await tester.tap(find.text('المهام').last);
    await tester.pumpAndSettle();
    expect(find.text('أحل شيت 3 برمجة'), findsOneWidget);
    await tester.tap(find.text('كويزات'));
    await tester.pumpAndSettle();
    expect(find.textContaining('كويز: كويز 2'), findsOneWidget);
    await tester.tap(find.text('أسايمنتات'));
    await tester.pumpAndSettle();
    expect(find.textContaining('ERD لمكتبة'), findsOneWidget);
    await tester.tap(find.text('مشاريع'));
    await tester.pumpAndSettle();
    expect(find.text('مشروع إدارة مكتبة'), findsOneWidget);

    await tester.tap(find.text('المواد').last);
    await tester.pumpAndSettle();
    expect(find.text('مستواك لحد دلوقتي'), findsOneWidget);
    await tester.tap(find.text('برمجة 2'));
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.text('محتاج كام عشان تجيب…'));
    await _scrollTo(tester, find.textContaining('بونص').last);
    await _scrollTo(tester, find.text(fraction(8.5, 10)));

    for (final tab in ['المذاكرة', 'المواعيد', 'الجدول']) {
      await tester.tap(find.widgetWithText(Tab, tab));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('adding a subject and a grade', (tester) async {
    final store = await _pumpApp(tester);

    await tester.tap(find.text('المواد').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('مادة جديدة'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'فيزياء');
    await tester.tap(find.text('حفظ').first);
    await tester.pumpAndSettle();
    expect(store.subjects.single.name, 'فيزياء');

    await tester.tap(find.text('فيزياء'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('درجة جديدة'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'خدت كام'), '٨');
    await tester.enterText(find.widgetWithText(TextFormField, 'من كام'), '10');
    await tester.tap(find.text('حفظ').first);
    await tester.pumpAndSettle();

    final grade = store.grades.single;
    expect(grade.score, 8);
    expect(grade.maxScore, 10);
    expect(find.text('80%'), findsOneWidget);
  });
}
