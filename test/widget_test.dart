import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:study_planner/app.dart';
import 'package:study_planner/data/app_store.dart';
import 'package:study_planner/data/storage.dart';
import 'package:study_planner/models/models.dart';
import 'package:study_planner/utils/formatters.dart';

/// The visible vertical list, to scroll lazily built items into view.
Finder get _list => find
    .byWidgetPredicate((w) => w is Scrollable && w.axis == Axis.vertical)
    .last;

Future<void> _scrollTo(WidgetTester tester, Finder finder) =>
    tester.scrollUntilVisible(finder, 250, scrollable: _list);

/// Scrolls until [finder] (which may match several widgets) is built, then
/// brings its first match to the middle of the screen, away from the FAB.
Future<void> _center(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 30 && finder.evaluate().isEmpty; i++) {
    await tester.drag(_list, const Offset(0, -250));
    await tester.pumpAndSettle();
  }
  await Scrollable.ensureVisible(tester.element(finder.first), alignment: 0.5);
  await tester.pumpAndSettle();
}

Future<AppStore> _pumpApp(WidgetTester tester, {bool demo = false}) async {
  // A typical phone screen, so layout overflows show up as failures.
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final store = AppStore(MemoryStorage());
  await store.load();
  await tester.pumpWidget(StudyPlannerApp(store: store));
  await tester.pumpAndSettle();
  if (demo) {
    await tester.tap(find.text('جرّب ببيانات تجريبية'));
    await tester.pumpAndSettle();
  }
  return store;
}

Future<void> _tapTab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('ar'));

  testWidgets('first launch shows onboarding and loads demo data', (
    tester,
  ) async {
    await _pumpApp(tester);
    expect(find.text('أهلاً بيك!'), findsOneWidget);

    await tester.tap(find.text('جرّب ببيانات تجريبية'));
    await tester.pumpAndSettle();

    expect(find.text('أهلاً بيك!'), findsNothing);
    expect(find.text('مذاكرة النهارده'), findsOneWidget);
    await _scrollTo(tester, find.text('جدول النهارده'));
    await _scrollTo(tester, find.text('كويزات وتسليمات قريبة'));
    await _scrollTo(tester, find.textContaining('تاسكات عليك'));
    await _scrollTo(tester, find.text('مشروع إدارة مكتبة'));
  });

  testWidgets('study tab: mark studied and do a due review', (tester) async {
    final store = await _pumpApp(tester, demo: true);
    await _tapTab(tester, 'المذاكرة');
    expect(find.text('ابدأ جلسة تركيز'), findsOneWidget);

    final reviewsBefore = store.dueReviews(DateTime.now()).length;
    expect(reviewsBefore, greaterThan(0));
    await _center(tester, find.text('راجعتها'));
    await tester.tap(find.text('راجعتها').first);
    await tester.pumpAndSettle();
    expect(store.dueReviews(DateTime.now()), hasLength(reviewsBefore - 1));

    final doneBefore = store.studyItems.where((s) => s.status.isDone).length;
    await _center(tester, find.byTooltip('اتذاكرت'));
    await tester.tap(find.byTooltip('اتذاكرت').first);
    await tester.pumpAndSettle();
    expect(
      store.studyItems.where((s) => s.status.isDone).length,
      doneBefore + 1,
    );
  });

  testWidgets('every tab and the subject pages render', (tester) async {
    await _pumpApp(tester, demo: true);

    await _tapTab(tester, 'الجدول');
    expect(find.text('ميعاد جديد'), findsOneWidget);

    await _tapTab(tester, 'المهام');
    expect(find.text('أحل شيت 3 برمجة'), findsOneWidget);
    await _tapTab(tester, 'كويزات');
    expect(find.textContaining('كويز: كويز 2'), findsOneWidget);
    await _tapTab(tester, 'أسايمنتات');
    expect(find.textContaining('ERD لمكتبة'), findsOneWidget);
    await _tapTab(tester, 'مشاريع');
    expect(find.text('مشروع إدارة مكتبة'), findsOneWidget);

    await _tapTab(tester, 'المواد');
    expect(find.text('مستواك لحد دلوقتي'), findsOneWidget);
    await tester.tap(find.text('برمجة 2'));
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.text('محتاج كام عشان تجيب…'));
    await _scrollTo(tester, find.textContaining('بونص').last);
    await _scrollTo(tester, find.text(fraction(8.5, 10)));

    for (final tab in ['المذاكرة', 'المواعيد', 'الحضور']) {
      await tester.tap(find.widgetWithText(Tab, tab));
      await tester.pumpAndSettle();
    }
    expect(find.text('نسبة حضورك'), findsOneWidget);
  });

  testWidgets('focus timer starts and stops', (tester) async {
    final store = await _pumpApp(tester, demo: true);
    await tester.tap(find.text('ذاكر'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('يلا نبدأ'));
    await tester.pump(const Duration(seconds: 2));
    expect(store.focus, isNotNull);
    expect(store.focus!.phase, FocusPhase.focus);

    await tester.tap(find.text('وقفة'));
    await tester.pump(const Duration(seconds: 1));
    expect(store.focus!.isPaused, isTrue);

    final sessions = store.studySessions.length;
    await tester.tap(find.text('إيقاف'));
    await tester.pump(const Duration(seconds: 1));
    expect(store.focus, isNull);
    // Less than a minute of focus is not logged.
    expect(store.studySessions, hasLength(sessions));
  });

  testWidgets('stats screen and GPA mode', (tester) async {
    final store = await _pumpApp(tester, demo: true);
    await tester.tap(find.byTooltip('الإحصائيات').first);
    await tester.pumpAndSettle();
    expect(find.text('آخر 7 أيام'), findsOneWidget);
    Navigator.of(tester.element(find.text('آخر 7 أيام'))).pop();
    await tester.pumpAndSettle();

    await store.updateSettings(
      store.settings.copyWith(gradingSystem: GradingSystem.gpa),
    );
    await _tapTab(tester, 'المواد');
    expect(find.text('المعدل التراكمي المتوقع'), findsOneWidget);
  });

  testWidgets('adding a subject and a grade', (tester) async {
    final store = await _pumpApp(tester);

    await _tapTab(tester, 'المواد');
    await tester.tap(find.text('مادة جديدة'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'فيزياء');
    await tester.tap(find.text('حفظ').first);
    await tester.pumpAndSettle();
    expect(store.subjects.single.name, 'فيزياء');
    expect(store.subjects.single.creditHours, 3);

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
    expect(find.text('80%'), findsWidgets);
  });
}
