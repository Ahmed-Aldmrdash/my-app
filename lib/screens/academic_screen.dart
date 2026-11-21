import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/academic.dart';
import '../utils/formatters.dart';
import '../utils/grade_calculator.dart';
import '../utils/ids.dart';
import '../widgets/common.dart';

/// Text for a cumulative average in the chosen [system].
String averageText(double? gpa, double? percent, GradingSystem system) {
  if (system == GradingSystem.gpa) {
    return gpa == null ? '—' : gpa.toStringAsFixed(2);
  }
  return percent == null
      ? '—'
      : '${formatPercent(percent)} ${gradeLabel(percent)}';
}

/// The semesters archive with the cumulative GPA, and the study plan
/// towards graduation.
class AcademicScreen extends StatefulWidget {
  const AcademicScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<AcademicScreen> createState() => _AcademicScreenState();
}

class _AcademicScreenState extends State<AcademicScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: 2,
    vsync: this,
    initialIndex: widget.initialTab,
  )..addListener(() => setState(() {}));

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onPlan = _tabs.index == 1;
    return Scaffold(
      appBar: AppBar(
        title: const Text('الترمات والخطة'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'الترمات والمعدل'),
            Tab(text: 'خطة التخرج'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'academic-fab',
        onPressed: () => onPlan
            ? pushPage(context, const PlanCourseForm())
            : _addPastSemester(context),
        icon: const Icon(Icons.add_rounded),
        label: Text(onPlan ? 'مادة في الخطة' : 'ترم قديم'),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [_SemestersTab(), _PlanTab()],
      ),
    );
  }
}

Future<void> _addPastSemester(BuildContext context) async {
  final store = context.read<AppStore>();
  final name = await _askName(context, 'اسم الترم', '');
  if (name == null || name.isEmpty) return;
  // An old semester goes before the ones already there; the menu moves it.
  final order = store.semesters.fold(1, (m, s) => s.order < m ? s.order : m);
  await store.saveSemester(Semester(id: newId(), name: name, order: order - 1));
}

Future<String?> _askName(BuildContext context, String title, String initial) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'مثلاً: الترم الأول 2025/2026',
        ),
        onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, controller.text.trim()),
          child: const Text('حفظ'),
        ),
      ],
    ),
  ).whenComplete(controller.dispose);
}

class _SemestersTab extends StatelessWidget {
  const _SemestersTab();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final system = store.settings.gradingSystem;
    final record = store.academicRecord;
    final subjects = store.currentSubjects;
    final current = [for (final s in subjects) store.gradeSummary(s)];
    final theme = Theme.of(context);
    const white = Colors.white;
    final currentHours = subjects.fold(0, (sum, s) => sum + s.creditHours);
    final semesterName = store.settings.semesterName.trim();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        AppCard(
          gradient: AppColors.heroGradient,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                system == GradingSystem.gpa
                    ? 'المعدل التراكمي (GPA)'
                    : 'التقدير التراكمي',
                style: TextStyle(color: white.withValues(alpha: 0.85)),
              ),
              Text(
                averageText(record.gpa, record.percent, system),
                style: const TextStyle(
                  color: white,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'المتوقع بعد الترم ده: ${averageText(record.projectedGpa(current), record.projectedPercent(current), system)}',
                style: const TextStyle(
                  color: white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'خلصت ${hoursText(record.passedHours)}'
                '${store.settings.graduationHours > 0 ? ' من ${store.settings.graduationHours}' : ''}',
                style: TextStyle(color: white.withValues(alpha: 0.85)),
              ),
            ],
          ),
        ),
        SectionHeader(
          semesterName.isEmpty ? 'الترم الحالي' : semesterName,
          icon: Icons.play_circle_outline_rounded,
          trailing: IconButton(
            tooltip: 'غيّر اسم الترم',
            icon: const Icon(Icons.edit_rounded, size: 20),
            onPressed: () async {
              final name = await _askName(
                context,
                'اسم الترم الحالي',
                semesterName,
              );
              if (name == null) return;
              await store.updateSettings(
                store.settings.copyWith(semesterName: name),
              );
            },
          ),
        ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                subjects.isEmpty
                    ? 'لسه مفيش مواد في الترم ده'
                    : '${countText(subjects.length, 'مادة واحدة', 'مادتين', 'مواد', 'مادة')} • ${hoursText(currentHours)} • '
                          'متوقع ${averageText(expectedGpa(current), overallPercent(current), system)}',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: subjects.isEmpty
                    ? null
                    : () => pushPage(context, const CloseSemesterScreen()),
                icon: const Icon(Icons.inventory_2_outlined),
                label: const Text('قفل الترم وابدأ ترم جديد'),
              ),
            ],
          ),
        ),
        if (record.terms.isNotEmpty)
          const SectionHeader('الأرشيف', icon: Icons.inventory_2_rounded),
        for (final t in record.terms) _TermCard(term: t),
        if (record.terms.isEmpty)
          const EmptyState(
            icon: Icons.history_edu_rounded,
            title: 'الأرشيف فاضي',
            message:
                'لما تقفل الترم بدرجاتك النهائية هيتحفظ هنا. وتقدر تضيف '
                'ترماتك القديمة بموادها وتقديراتها عشان المعدل التراكمي يتحسب صح',
          ),
      ],
    );
  }
}

/// Swaps [semester] with the next newer (or older) one in the archive,
/// numbering them all again so their order is unambiguous.
Future<void> _move(
  AppStore store,
  Semester semester, {
  required bool newer,
}) async {
  final sorted = [...store.semesters]
    ..sort((a, b) => a.order.compareTo(b.order));
  final i = sorted.indexWhere((s) => s.id == semester.id);
  final j = newer ? i + 1 : i - 1;
  if (i < 0 || j < 0 || j >= sorted.length) return;
  final moved = sorted[i];
  sorted[i] = sorted[j];
  sorted[j] = moved;
  for (var k = 0; k < sorted.length; k++) {
    final s = sorted[k];
    if (s.order == k + 1) continue;
    await store.saveSemester(
      Semester(id: s.id, name: s.name, order: k + 1, notes: s.notes),
    );
  }
}

class _TermCard extends StatelessWidget {
  const _TermCard({required this.term});

  final TermResult term;

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final system = store.settings.gradingSystem;
    final theme = Theme.of(context);
    final semester = term.semester;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      semester?.name ?? 'ترم مش معروف',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${term.hours} ساعة • ${averageText(term.gpa, term.percent, system)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (semester != null)
                IconButton(
                  tooltip: 'ضيف مادة للترم ده',
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  onPressed: () => pushPage(
                    context,
                    PlanCourseForm(initialSemesterId: semester.id),
                  ),
                ),
              if (semester != null)
                PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'rename') {
                      final name = await _askName(
                        context,
                        'اسم الترم',
                        semester.name,
                      );
                      if (name == null || name.isEmpty) return;
                      await store.saveSemester(
                        Semester(
                          id: semester.id,
                          name: name,
                          order: semester.order,
                          notes: semester.notes,
                        ),
                      );
                    } else if (v == 'newer' || v == 'older') {
                      await _move(store, semester, newer: v == 'newer');
                    } else if (v == 'delete' && context.mounted) {
                      final ok = await confirmDelete(
                        context,
                        'تمسح "${semester.name}"؟',
                        message:
                            'المواد هتفضل في خطة التخرج بس من غير تقديراتها.',
                      );
                      if (ok) await store.deleteSemester(semester.id);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'rename', child: Text('غيّر الاسم')),
                    PopupMenuItem(value: 'newer', child: Text('انقله لفوق')),
                    PopupMenuItem(value: 'older', child: Text('انقله لتحت')),
                    PopupMenuItem(value: 'delete', child: Text('حذف')),
                  ],
                ),
            ],
          ),
          for (final c in term.courses)
            ListTile(
              dense: true,
              contentPadding: const EdgeInsetsDirectional.only(end: 8),
              onTap: () => pushPage(context, PlanCourseForm(course: c)),
              title: Text(c.name),
              subtitle: Text(
                '${c.creditHours} ساعة${c.code.isEmpty ? '' : ' • ${c.code}'}',
              ),
              trailing: Pill(
                courseGradeText(c, system) ?? 'من غير تقدير',
                color: coursePassed(c) ? AppColors.teal : AppColors.danger,
              ),
            ),
        ],
      ),
    );
  }
}

class _PlanTab extends StatelessWidget {
  const _PlanTab();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final record = store.academicRecord;
    final theme = Theme.of(context);
    final required = store.settings.graduationHours;
    final remaining = record.remaining;
    final studying = store.currentSubjects;
    final current = remaining
        .where(
          (c) =>
              store.subjectById(c.subjectId) != null ||
              studying.any((s) => courseMatchesSubject(c, s)),
        )
        .toList();
    final waiting = remaining.where((c) => !current.contains(c)).toList();
    final available = waiting.where(record.prerequisitesMet).toList();
    final blocked = waiting.where((c) => !record.prerequisitesMet(c)).toList();
    final finished = record.courses.where((c) => c.isFinished).toList();
    final plannedHours = record.courses.fold(0, (s, c) => s + c.creditHours);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  ProgressRing(
                    value: required > 0 ? record.passedHours / required : 0,
                    size: 72,
                    stroke: 8,
                    child: Text(
                      required > 0
                          ? '${(record.passedHours / required * 100).clamp(0, 100).round()}%'
                          : '—',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          required > 0
                              ? 'خلصت ${record.passedHours} من $required ساعة'
                              : 'خلصت ${hoursText(record.passedHours)}',
                          style: theme.textTheme.titleMedium,
                        ),
                        Text(
                          required > 0
                              ? 'فاضلك ${(required - record.passedHours).clamp(0, 1000)} ساعة للتخرج'
                              : 'حدد عدد ساعات التخرج عشان أحسبلك فاضلك قد إيه',
                          style: theme.textTheme.bodySmall,
                        ),
                        if (plannedHours > 0)
                          Text(
                            'في الخطة: ${record.courses.length} مادة • $plannedHours ساعة',
                            style: theme.textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => _editGraduationHours(context, store),
                icon: const Icon(Icons.flag_rounded),
                label: const Text('ساعات التخرج'),
              ),
            ],
          ),
        ),
        if (record.courses.isEmpty)
          const EmptyState(
            icon: Icons.account_tree_rounded,
            title: 'ضيف مواد الخطة الدراسية',
            message:
                'ضيف كل مواد الكلية بساعاتها ومتطلباتها، وأنا هقولك خلصت إيه '
                'وفاضلك إيه وتقدر تسجل إيه الترم الجاي',
          ),
        if (current.isNotEmpty) ...[
          const SectionHeader(
            'بتدرسها دلوقتي',
            icon: Icons.play_circle_outline_rounded,
          ),
          for (final c in current) _CourseTile(course: c, record: record),
        ],
        if (available.isNotEmpty) ...[
          const SectionHeader('تقدر تسجلها', icon: Icons.lock_open_rounded),
          for (final c in available) _CourseTile(course: c, record: record),
        ],
        if (blocked.isNotEmpty) ...[
          const SectionHeader(
            'محتاجة متطلبات الأول',
            icon: Icons.lock_outline_rounded,
          ),
          for (final c in blocked) _CourseTile(course: c, record: record),
        ],
        if (finished.isNotEmpty) ...[
          const SectionHeader('خلصتها', icon: Icons.task_alt_rounded),
          for (final c in finished) _CourseTile(course: c, record: record),
        ],
      ],
    );
  }

  Future<void> _editGraduationHours(
    BuildContext context,
    AppStore store,
  ) async {
    final controller = TextEditingController(
      text: store.settings.graduationHours > 0
          ? '${store.settings.graduationHours}'
          : '',
    );
    final value = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('عدد ساعات التخرج'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'مثلاً 140'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, parseNumber(controller.text)?.round() ?? 0),
            child: const Text('حفظ'),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
    if (value == null) return;
    await store.updateSettings(
      store.settings.copyWith(graduationHours: value.clamp(0, 400)),
    );
  }
}

class _CourseTile extends StatelessWidget {
  const _CourseTile({required this.course, required this.record});

  final PlanCourse course;
  final AcademicRecord record;

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final system = store.settings.gradingSystem;
    final theme = Theme.of(context);
    final missing = record.missingPrerequisites(course);
    final details = [
      '${course.creditHours} ساعة',
      if (course.code.isNotEmpty) course.code,
      if (course.level > 0) 'فرقة ${course.level}',
      if (course.group.isNotEmpty) course.group,
    ].join(' • ');
    return AppCard(
      onTap: () => pushPage(context, PlanCourseForm(course: course)),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course.name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(details, style: theme.textTheme.bodySmall),
                if (!course.isFinished && missing.isNotEmpty)
                  Text(
                    'محتاج: ${missing.map((c) => c.name).join('، ')}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.orange,
                    ),
                  ),
              ],
            ),
          ),
          if (course.isFinished)
            Pill(
              courseGradeText(course, system) ?? 'خلصت',
              color: coursePassed(course) ? AppColors.teal : AppColors.danger,
            ),
        ],
      ),
    );
  }
}

/// Adds or edits a course of the study plan, optionally with its result.
class PlanCourseForm extends StatefulWidget {
  const PlanCourseForm({super.key, this.course, this.initialSemesterId});

  final PlanCourse? course;
  final String? initialSemesterId;

  @override
  State<PlanCourseForm> createState() => _PlanCourseFormState();
}

class _PlanCourseFormState extends State<PlanCourseForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.course?.name);
  late final _code = TextEditingController(text: widget.course?.code);
  late final _hours = TextEditingController(
    text: '${widget.course?.creditHours ?? 3}',
  );
  late final _percent = TextEditingController(
    text: widget.course?.percent == null
        ? ''
        : formatNumber(widget.course!.percent!),
  );
  late String _group = widget.course?.group ?? '';
  late int _level = widget.course?.level ?? 0;
  late final Set<String> _prereqs = {...?widget.course?.prerequisites};
  late String? _semesterId =
      widget.course?.semesterId ?? widget.initialSemesterId;
  late String? _letter = widget.course?.letter;

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _hours.dispose();
    _percent.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final old = widget.course;
    final finished = _semesterId != null;
    await context.read<AppStore>().saveCourse(
      PlanCourse(
        id: old?.id ?? newId(),
        name: _name.text.trim(),
        code: _code.text.trim(),
        creditHours: parseNumber(_hours.text)?.round().clamp(0, 30) ?? 3,
        group: _group,
        level: _level,
        prerequisites: _prereqs.toList(),
        semesterId: _semesterId,
        percent: finished
            ? parseNumber(_percent.text)?.clamp(0, 100).toDouble()
            : null,
        letter: finished ? _letter : null,
        subjectId: finished ? null : old?.subjectId,
        notes: old?.notes ?? '',
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    if (!await confirmDelete(context, 'تمسح المادة دي من الخطة؟')) return;
    if (!mounted) return;
    await context.read<AppStore>().deleteCourse(widget.course!.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final editing = widget.course != null;
    final others =
        store.planCourses.where((c) => c.id != widget.course?.id).toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    final semesters = [...store.semesters]
      ..sort((a, b) => b.order.compareTo(a.order));
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'تعديل المادة' : 'مادة في الخطة'),
        actions: [
          if (editing)
            IconButton(
              tooltip: 'حذف',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
          TextButton(onPressed: _save, child: const Text('حفظ')),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ReadableWidth(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _name,
                autofocus: !editing,
                decoration: const InputDecoration(
                  labelText: 'اسم المادة',
                  prefixIcon: Icon(Icons.school_rounded),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'اكتب اسم المادة' : null,
              ),
              formGap,
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _code,
                      textDirection: TextDirection.ltr,
                      decoration: const InputDecoration(
                        labelText: 'الكود',
                        prefixIcon: Icon(Icons.tag_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _hours,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'الساعات',
                        prefixIcon: Icon(Icons.schedule_rounded),
                      ),
                    ),
                  ),
                ],
              ),
              formGap,
              Text('النوع', style: theme.textTheme.labelLarge),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final g in courseGroups)
                    ChoiceChip(
                      label: Text(g),
                      selected: _group == g,
                      onSelected: (on) => setState(() => _group = on ? g : ''),
                    ),
                ],
              ),
              formGap,
              Text('الفرقة', style: theme.textTheme.labelLarge),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  for (var l = 0; l <= 5; l++)
                    ChoiceChip(
                      label: Text(l == 0 ? 'مش محدد' : '$l'),
                      selected: _level == l,
                      onSelected: (_) => setState(() => _level = l),
                    ),
                ],
              ),
              if (others.isNotEmpty) ...[
                formGap,
                Text('المتطلبات السابقة', style: theme.textTheme.labelLarge),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final c in others)
                      FilterChip(
                        label: Text(c.name),
                        selected: _prereqs.contains(c.id),
                        onSelected: (on) => setState(
                          () => on ? _prereqs.add(c.id) : _prereqs.remove(c.id),
                        ),
                      ),
                  ],
                ),
              ],
              formGap,
              FormSection(
                title: 'النتيجة',
                icon: Icons.workspace_premium_rounded,
                children: [
                  DropdownButtonFormField<String?>(
                    initialValue: semesters.any((s) => s.id == _semesterId)
                        ? _semesterId
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'خلصتها في ترم',
                      prefixIcon: Icon(Icons.inventory_2_outlined),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('لسه ما خلصتهاش'),
                      ),
                      for (final s in semesters)
                        DropdownMenuItem(value: s.id, child: Text(s.name)),
                    ],
                    onChanged: (v) => setState(() => _semesterId = v),
                  ),
                  if (semesters.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'ضيف الترم الأول من تبويب "الترمات والمعدل"',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  if (_semesterId != null) ...[
                    formGap,
                    TextFormField(
                      controller: _percent,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'الدرجة النهائية % (اختياري)',
                        prefixIcon: Icon(Icons.percent_rounded),
                      ),
                    ),
                    formGap,
                    DropdownButtonFormField<String?>(
                      initialValue: _letter,
                      decoration: const InputDecoration(
                        labelText: 'التقدير بالحروف (اختياري)',
                        prefixIcon: Icon(Icons.grade_rounded),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('من الدرجة'),
                        ),
                        for (final g in gpaScale)
                          DropdownMenuItem(
                            value: g.letter,
                            child: Text(ltr('${g.letter} (${g.points})')),
                          ),
                      ],
                      onChanged: (v) => setState(() => _letter = v),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check),
                label: const Text('حفظ'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Closes the current semester: records each subject's final grade in the
/// archive and the study plan, then optionally clears the semester's data.
class CloseSemesterScreen extends StatefulWidget {
  const CloseSemesterScreen({super.key});

  @override
  State<CloseSemesterScreen> createState() => _CloseSemesterScreenState();
}

class _CloseSemesterScreenState extends State<CloseSemesterScreen> {
  late final AppStore _store = context.read<AppStore>();
  late final _name = TextEditingController(text: _store.settings.semesterName);
  final _next = TextEditingController();

  /// The subjects being closed, fixed when the screen opens.
  late final List<Subject> _subjects = _store.currentSubjects;
  late final Map<String, TextEditingController> _percents = {
    for (final s in _subjects)
      s.id: TextEditingController(
        text: switch (_store.gradeSummary(s).percentSoFar) {
          final p? => formatNumber(p.roundToDouble()),
          null => '',
        },
      ),
  };
  final Map<String, String?> _letters = {};
  bool _clear = true;

  @override
  void dispose() {
    _name.dispose();
    _next.dispose();
    for (final c in _percents.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _close() async {
    final ok = await confirmDelete(
      context,
      'نقفل الترم؟',
      message: _clear
          ? 'الدرجات النهائية هتتحفظ في الأرشيف، وبعدين هيتمسح جدول ومحاضرات '
                'ودرجات وكويزات وحضور وملاحظات وكروت مواد الترم ده. '
                'لو عايز نسخة من كل حاجة اعمل نسخة احتياطية من الإعدادات الأول.'
          : 'الدرجات النهائية هتتحفظ في الأرشيف وكل بيانات الترم هتفضل زي ما هي.',
      confirmLabel: 'اقفل الترم',
    );
    if (!ok || !mounted) return;
    final semester = await _store.closeSemester(
      name: _name.text.trim(),
      nextName: _next.text.trim(),
      clearData: _clear,
      results: {
        for (final s in _subjects)
          s.id: (
            percent: parseNumber(
              _percents[s.id]?.text ?? '',
            )?.clamp(0, 100).toDouble(),
            letter: _letters[s.id],
          ),
      },
    );
    if (!mounted) return;
    showSnack(context, 'اتحفظ "${semester.name}" في الأرشيف 🎓');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final system = _store.settings.gradingSystem;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('قفل الترم')),
      body: ReadableWidth(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'اسم الترم اللي خلص',
                hintText: 'مثلاً: الترم الأول 2025/2026',
                prefixIcon: Icon(Icons.inventory_2_outlined),
              ),
            ),
            formGap,
            Text(
              'الدرجة النهائية لكل مادة (من 100). حطيتلك نسبتك لحد دلوقتي، '
              'عدّلها لما النتيجة تظهر.',
              style: theme.textTheme.bodySmall,
            ),
            for (final s in _subjects)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        '${s.name} (${s.creditHours} س)',
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _percents[s.id],
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: '%',
                          isDense: true,
                        ),
                      ),
                    ),
                    if (system == GradingSystem.gpa) ...[
                      const SizedBox(width: 8),
                      DropdownButton<String?>(
                        value: _letters[s.id],
                        hint: const Text('حرف'),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('تلقائي'),
                          ),
                          for (final g in gpaScale)
                            DropdownMenuItem(
                              value: g.letter,
                              child: Text(g.letter),
                            ),
                        ],
                        onChanged: (v) => setState(() => _letters[s.id] = v),
                      ),
                    ],
                  ],
                ),
              ),
            formGap,
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _clear,
              onChanged: (v) => setState(() => _clear = v),
              title: const Text('امسح بيانات الترم ده'),
              subtitle: const Text(
                'الجدول والمحاضرات والدرجات والكويزات والحضور والملاحظات والكروت. '
                'التاسكات والمشاريع هتفضل.',
              ),
            ),
            formGap,
            TextField(
              controller: _next,
              decoration: const InputDecoration(
                labelText: 'اسم الترم الجديد (اختياري)',
                prefixIcon: Icon(Icons.play_circle_outline_rounded),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _close,
              icon: const Icon(Icons.inventory_2_rounded),
              label: const Text('اقفل الترم'),
            ),
          ],
        ),
      ),
    );
  }
}
