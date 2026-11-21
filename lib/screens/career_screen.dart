import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/ids.dart';
import '../widgets/common.dart';
import 'notes_screen.dart';

extension AchievementKindLabel on AchievementKind {
  String get label => switch (this) {
    AchievementKind.course => 'كورس',
    AchievementKind.certificate => 'شهادة',
    AchievementKind.internship => 'تدريب',
    AchievementKind.activity => 'نشاط طلابي',
    AchievementKind.volunteering => 'تطوع',
    AchievementKind.competition => 'مسابقة',
    AchievementKind.skill => 'مهارة',
  };

  /// Section title in the CV.
  String get plural => switch (this) {
    AchievementKind.course => 'الكورسات',
    AchievementKind.certificate => 'الشهادات',
    AchievementKind.internship => 'التدريب',
    AchievementKind.activity => 'الأنشطة',
    AchievementKind.volunteering => 'التطوع',
    AchievementKind.competition => 'المسابقات',
    AchievementKind.skill => 'المهارات',
  };

  IconData get icon => switch (this) {
    AchievementKind.course => Icons.play_lesson_rounded,
    AchievementKind.certificate => Icons.workspace_premium_rounded,
    AchievementKind.internship => Icons.business_center_rounded,
    AchievementKind.activity => Icons.groups_2_rounded,
    AchievementKind.volunteering => Icons.volunteer_activism_rounded,
    AchievementKind.competition => Icons.emoji_events_rounded,
    AchievementKind.skill => Icons.bolt_rounded,
  };

  Color get color => switch (this) {
    AchievementKind.course => AppColors.sky,
    AchievementKind.certificate => AppColors.amber,
    AchievementKind.internship => AppColors.primary,
    AchievementKind.activity => AppColors.teal,
    AchievementKind.volunteering => AppColors.pink,
    AchievementKind.competition => AppColors.orange,
    AchievementKind.skill => AppColors.cyan,
  };
}

/// "سبتمبر 2026 – دلوقتي" and similar.
String achievementDates(Achievement a) {
  String month(DateTime d) => latinDigits('${monthNames[d.month]} ${d.year}');
  final start = a.start;
  final end = a.end;
  if (start == null && end == null) return a.ongoing ? 'لسه مستمر' : '';
  if (start == null) return month(end!);
  if (a.ongoing) return '${month(start)} – دلوقتي';
  if (end == null || (end.year == start.year && end.month == start.month)) {
    return month(start);
  }
  return '${month(start)} – ${month(end)}';
}

const monthNames = {
  1: 'يناير',
  2: 'فبراير',
  3: 'مارس',
  4: 'أبريل',
  5: 'مايو',
  6: 'يونيو',
  7: 'يوليو',
  8: 'أغسطس',
  9: 'سبتمبر',
  10: 'أكتوبر',
  11: 'نوفمبر',
  12: 'ديسمبر',
};

/// Everything for the CV as plain text, ready to paste.
String cvText(AppStore store) {
  final buf = StringBuffer();
  final name = store.settings.studentName.trim();
  if (name.isNotEmpty) buf.writeln(name);
  final record = store.academicRecord;
  final system = store.settings.gradingSystem;
  if (record.gpa != null || record.percent != null) {
    buf.writeln(
      system == GradingSystem.gpa
          ? 'المعدل التراكمي: ${record.gpa?.toStringAsFixed(2) ?? '—'}'
          : 'التقدير التراكمي: ${formatPercent(record.percent)}',
    );
  }
  if (record.passedHours > 0) {
    buf.writeln('الساعات المكتملة: ${record.passedHours}');
  }
  for (final kind in AchievementKind.values) {
    final items = store.achievementsSorted
        .where((a) => a.kind == kind)
        .toList();
    if (items.isEmpty) continue;
    buf
      ..writeln()
      ..writeln(kind.plural);
    for (final a in items) {
      final parts = [
        a.title,
        if (a.organization.isNotEmpty) a.organization,
        if (achievementDates(a).isNotEmpty) achievementDates(a),
      ];
      buf.writeln('• ${parts.join(' — ')}');
      if (a.description.isNotEmpty) buf.writeln('  ${a.description}');
      if (a.url.isNotEmpty) buf.writeln('  ${a.url}');
    }
  }
  return buf.toString().trim();
}

/// Courses, certificates, internships, activities and skills, with a CV
/// summary.
class CareerScreen extends StatefulWidget {
  const CareerScreen({super.key});

  @override
  State<CareerScreen> createState() => _CareerScreenState();
}

class _CareerScreenState extends State<CareerScreen> {
  AchievementKind? _kind;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final all = store.achievementsSorted;
    final shown = all.where((a) => _kind == null || a.kind == _kind).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('الكورسات والـ CV'),
        actions: [
          IconButton(
            tooltip: 'ملخص الـ CV',
            icon: const Icon(Icons.description_rounded),
            onPressed: () => _showCv(context, store),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'career-fab',
        onPressed: () => pushPage(context, AchievementForm(initialKind: _kind)),
        icon: const Icon(Icons.add_rounded),
        label: const Text('ضيف'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('الكل'),
                  selected: _kind == null,
                  onSelected: (_) => setState(() => _kind = null),
                ),
                for (final k in AchievementKind.values) ...[
                  const SizedBox(width: 6),
                  ChoiceChip(
                    label: Text(k.label),
                    selected: _kind == k,
                    onSelected: (_) => setState(() => _kind = k),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 6),
          if (shown.isEmpty)
            const EmptyState(
              icon: Icons.workspace_premium_rounded,
              title: 'ابدأ تبني الـ CV بتاعك',
              message:
                  'سجل كل كورس وشهادة وتدريب ونشاط، وأنا أجمعهولك في ملخص '
                  'تنسخه في الـ CV',
            )
          else
            for (final a in shown) _AchievementTile(item: a),
        ],
      ),
    );
  }

  void _showCv(BuildContext context, AppStore store) {
    final text = cvText(store);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('ملخص للـ CV', style: Theme.of(sheet).textTheme.titleMedium),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(sheet).height * 0.55,
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    text.isEmpty ? 'لسه مفيش حاجة تتكتب' : text,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: text.isEmpty
                    ? null
                    : () async {
                        await Clipboard.setData(ClipboardData(text: text));
                        if (sheet.mounted) showSnack(sheet, 'اتنسخ ✓');
                      },
                icon: const Icon(Icons.copy_rounded),
                label: const Text('انسخ'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({required this.item});

  final Achievement item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dates = achievementDates(item);
    return AppCard(
      onTap: () => pushPage(context, AchievementForm(item: item)),
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      child: Row(
        children: [
          IconBadge(item.kind.icon, color: item.kind.color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  [
                    item.kind.label,
                    if (item.organization.isNotEmpty) item.organization,
                    if (dates.isNotEmpty) dates,
                  ].join(' • '),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (item.url.isNotEmpty)
            IconButton(
              tooltip: 'افتح اللينك',
              icon: const Icon(Icons.open_in_new_rounded),
              onPressed: () => openLink(context, item.url),
            ),
        ],
      ),
    );
  }
}

/// Adds or edits a course, certificate, internship…
class AchievementForm extends StatefulWidget {
  const AchievementForm({super.key, this.item, this.initialKind});

  final Achievement? item;
  final AchievementKind? initialKind;

  @override
  State<AchievementForm> createState() => _AchievementFormState();
}

class _AchievementFormState extends State<AchievementForm> {
  final _formKey = GlobalKey<FormState>();
  late AchievementKind _kind =
      widget.item?.kind ?? widget.initialKind ?? AchievementKind.course;
  late final _title = TextEditingController(text: widget.item?.title);
  late final _org = TextEditingController(text: widget.item?.organization);
  late final _url = TextEditingController(text: widget.item?.url);
  late final _desc = TextEditingController(text: widget.item?.description);
  late DateTime? _start = widget.item?.start;
  late DateTime? _end = widget.item?.end;
  late bool _ongoing = widget.item?.ongoing ?? false;

  @override
  void dispose() {
    _title.dispose();
    _org.dispose();
    _url.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    await context.read<AppStore>().saveAchievement(
      Achievement(
        id: widget.item?.id ?? newId(),
        kind: _kind,
        title: _title.text.trim(),
        organization: _org.text.trim(),
        start: _start,
        end: _ongoing ? null : _end,
        ongoing: _ongoing,
        url: _url.text.trim().isEmpty ? '' : normalizeUrl(_url.text),
        description: _desc.text.trim(),
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    if (!await confirmDelete(context, 'تمسح "${widget.item!.title}"؟')) return;
    if (!mounted) return;
    await context.read<AppStore>().deleteAchievement(widget.item!.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.item != null;
    final skill = _kind == AchievementKind.skill;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'تعديل' : 'إضافة للـ CV'),
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
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final k in AchievementKind.values)
                    ChoiceChip(
                      avatar: Icon(k.icon, size: 18, color: k.color),
                      label: Text(k.label),
                      selected: _kind == k,
                      onSelected: (_) => setState(() => _kind = k),
                    ),
                ],
              ),
              formGap,
              TextFormField(
                controller: _title,
                autofocus: !editing,
                decoration: InputDecoration(
                  labelText: skill ? 'المهارة' : 'الاسم',
                  prefixIcon: const Icon(Icons.title_rounded),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'اكتب الاسم' : null,
              ),
              if (!skill) ...[
                formGap,
                TextFormField(
                  controller: _org,
                  decoration: const InputDecoration(
                    labelText: 'الجهة (المنصة، الشركة، الفريق…)',
                    prefixIcon: Icon(Icons.apartment_rounded),
                  ),
                ),
                formGap,
                DateTimeField(
                  label: 'بدأ إمتى',
                  value: _start,
                  withTime: false,
                  clearable: true,
                  onChanged: (d) => setState(() => _start = d),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _ongoing,
                  onChanged: (v) => setState(() => _ongoing = v),
                  title: const Text('لسه مستمر'),
                ),
                if (!_ongoing)
                  DateTimeField(
                    label: 'خلص إمتى',
                    value: _end,
                    withTime: false,
                    clearable: true,
                    onChanged: (d) => setState(() => _end = d),
                  ),
                formGap,
                TextFormField(
                  controller: _url,
                  keyboardType: TextInputType.url,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                    labelText: 'لينك الشهادة أو الشغل',
                    prefixIcon: Icon(Icons.link_rounded),
                  ),
                ),
              ],
              formGap,
              TextFormField(
                controller: _desc,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'عملت فيه إيه / اتعلمت إيه',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.notes),
                ),
              ),
              const SizedBox(height: 24),
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
