import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/ids.dart';
import '../utils/labels.dart';
import '../widgets/common.dart';
import 'notes_screen.dart';

extension ApplicationKindLabel on ApplicationKind {
  String get label => switch (this) {
    ApplicationKind.scholarship => 'منحة',
    ApplicationKind.internship => 'تدريب',
    ApplicationKind.job => 'شغل',
    ApplicationKind.competition => 'مسابقة',
    ApplicationKind.exchange => 'تبادل طلابي',
    ApplicationKind.other => 'حاجة تانية',
  };

  IconData get icon => switch (this) {
    ApplicationKind.scholarship => Icons.school_rounded,
    ApplicationKind.internship => Icons.business_center_rounded,
    ApplicationKind.job => Icons.work_rounded,
    ApplicationKind.competition => Icons.emoji_events_rounded,
    ApplicationKind.exchange => Icons.flight_takeoff_rounded,
    ApplicationKind.other => Icons.assignment_rounded,
  };
}

extension ApplicationStatusLabel on ApplicationStatus {
  String get label => switch (this) {
    ApplicationStatus.planning => 'لسه هقدّم',
    ApplicationStatus.applied => 'قدّمت',
    ApplicationStatus.interview => 'إنترفيو',
    ApplicationStatus.accepted => 'اتقبلت 🎉',
    ApplicationStatus.rejected => 'ماتقبلتش',
  };

  Color get color => switch (this) {
    ApplicationStatus.planning => AppColors.primary,
    ApplicationStatus.applied => AppColors.sky,
    ApplicationStatus.interview => AppColors.orange,
    ApplicationStatus.accepted => AppColors.teal,
    ApplicationStatus.rejected => AppColors.danger,
  };
}

/// Scholarships, internships and competitions to apply for.
class ApplicationsScreen extends StatelessWidget {
  const ApplicationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final all = store.applicationsSorted;
    final open = all.where((a) => a.isOpen).toList();
    final waiting = all
        .where(
          (a) =>
              a.status == ApplicationStatus.applied ||
              a.status == ApplicationStatus.interview,
        )
        .toList();
    final done = all
        .where(
          (a) =>
              a.status == ApplicationStatus.accepted ||
              a.status == ApplicationStatus.rejected,
        )
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('المنح والتقديمات')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'apps-fab',
        onPressed: () => pushPage(context, const ApplicationForm()),
        icon: const Icon(Icons.add_rounded),
        label: const Text('تقديم جديد'),
      ),
      body: all.isEmpty
          ? const EmptyState(
              icon: Icons.school_rounded,
              title: 'مفيش تقديمات',
              message:
                  'سجل المنح والتدريبات والمسابقات اللي عايز تقدّم فيها، '
                  'بمعاد آخر يوم والورق المطلوب، وأنا أفكرك',
            )
          : NowBuilder(
              builder: (context, now) => ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                children: [
                  if (open.isNotEmpty) ...[
                    const SectionHeader('هقدّم فيها', icon: Icons.edit_rounded),
                    for (final a in open) _ApplicationTile(item: a, now: now),
                  ],
                  if (waiting.isNotEmpty) ...[
                    const SectionHeader(
                      'مستني الرد',
                      icon: Icons.hourglass_top_rounded,
                    ),
                    for (final a in waiting)
                      _ApplicationTile(item: a, now: now),
                  ],
                  if (done.isNotEmpty) ...[
                    const SectionHeader('النتيجة', icon: Icons.flag_rounded),
                    for (final a in done) _ApplicationTile(item: a, now: now),
                  ],
                ],
              ),
            ),
    );
  }
}

class _ApplicationTile extends StatelessWidget {
  const _ApplicationTile({required this.item, required this.now});

  final Application item;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final deadline = item.deadline;
    return AppCard(
      onTap: () => pushPage(context, ApplicationForm(item: item)),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconBadge(item.kind.icon, color: item.status.color),
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
                        item.status.label,
                      ].join(' • '),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (item.isOpen && deadline != null)
                CountdownPill(due: deadline, now: now),
            ],
          ),
          if (item.isOpen && item.requirements.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'جهزت ${item.requirements.where((r) => r.done).length} من ${item.requirements.length}',
              style: theme.textTheme.labelMedium,
            ),
            const SizedBox(height: 4),
            RoundedProgress(value: item.readiness, color: item.status.color),
          ],
        ],
      ),
    );
  }
}

/// Adds or edits an application with its checklist.
class ApplicationForm extends StatefulWidget {
  const ApplicationForm({super.key, this.item});

  final Application? item;

  @override
  State<ApplicationForm> createState() => _ApplicationFormState();
}

class _ApplicationFormState extends State<ApplicationForm> {
  final _formKey = GlobalKey<FormState>();
  late ApplicationKind _kind = widget.item?.kind ?? ApplicationKind.scholarship;
  late ApplicationStatus _status =
      widget.item?.status ?? ApplicationStatus.planning;
  late final _title = TextEditingController(text: widget.item?.title);
  late final _org = TextEditingController(text: widget.item?.organization);
  late final _url = TextEditingController(text: widget.item?.url);
  late final _notes = TextEditingController(text: widget.item?.notes);
  final _newReq = TextEditingController();
  late DateTime? _deadline = widget.item?.deadline;
  late final List<ProjectStep> _reqs = [...?widget.item?.requirements];
  late List<int> _reminders = [
    ...(widget.item?.reminders ?? const [3 * 24 * 60, 24 * 60]),
  ];

  @override
  void dispose() {
    _title.dispose();
    _org.dispose();
    _url.dispose();
    _notes.dispose();
    _newReq.dispose();
    super.dispose();
  }

  void _addRequirement() {
    final t = _newReq.text.trim();
    if (t.isEmpty) return;
    setState(() {
      _reqs.add(ProjectStep(id: newId(), title: t));
      _newReq.clear();
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    _addRequirement();
    await context.read<AppStore>().saveApplication(
      Application(
        id: widget.item?.id ?? newId(),
        kind: _kind,
        title: _title.text.trim(),
        organization: _org.text.trim(),
        deadline: _deadline,
        status: _status,
        url: _url.text.trim().isEmpty ? '' : normalizeUrl(_url.text),
        requirements: _reqs,
        notes: _notes.text.trim(),
        reminders: _reminders,
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    if (!await confirmDelete(context, 'تمسح "${widget.item!.title}"؟')) return;
    if (!mounted) return;
    await context.read<AppStore>().deleteApplication(widget.item!.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.item != null;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'تعديل التقديم' : 'تقديم جديد'),
        actions: [
          if (editing && widget.item!.url.isNotEmpty)
            IconButton(
              tooltip: 'افتح اللينك',
              icon: const Icon(Icons.open_in_new_rounded),
              onPressed: () => openLink(context, widget.item!.url),
            ),
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
                  for (final k in ApplicationKind.values)
                    ChoiceChip(
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
                decoration: const InputDecoration(
                  labelText: 'اسمها',
                  prefixIcon: Icon(Icons.title_rounded),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'اكتب الاسم' : null,
              ),
              formGap,
              TextFormField(
                controller: _org,
                decoration: const InputDecoration(
                  labelText: 'الجهة',
                  prefixIcon: Icon(Icons.apartment_rounded),
                ),
              ),
              formGap,
              DateTimeField(
                label: 'آخر ميعاد للتقديم',
                value: _deadline,
                clearable: true,
                onChanged: (d) => setState(() => _deadline = d),
              ),
              formGap,
              Text('الحالة', style: theme.textTheme.labelLarge),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final s in ApplicationStatus.values)
                    ChoiceChip(
                      label: Text(s.label),
                      selected: _status == s,
                      onSelected: (_) => setState(() => _status = s),
                    ),
                ],
              ),
              formGap,
              Text('محتاج إيه؟', style: theme.textTheme.labelLarge),
              for (var i = 0; i < _reqs.length; i++)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _reqs[i].done,
                  onChanged: (v) => setState(
                    () => _reqs[i] = _reqs[i].copyWith(done: v ?? false),
                  ),
                  title: Text(_reqs[i].title),
                  secondary: IconButton(
                    tooltip: 'شيل',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => setState(() => _reqs.removeAt(i)),
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _newReq,
                      onSubmitted: (_) => _addRequirement(),
                      decoration: const InputDecoration(
                        hintText: 'مثلاً: CV، كشف درجات، جواب توصية',
                      ),
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'ضيف',
                    onPressed: _addRequirement,
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
              formGap,
              TextFormField(
                controller: _url,
                keyboardType: TextInputType.url,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                  labelText: 'لينك التقديم',
                  prefixIcon: Icon(Icons.link_rounded),
                ),
              ),
              if (_deadline != null) ...[
                formGap,
                Text('فكرني قبلها بـ', style: theme.textTheme.labelLarge),
                const SizedBox(height: 6),
                ReminderChips(
                  options: deadlineReminderOptions,
                  selected: _reminders,
                  onChanged: (v) => setState(() => _reminders = v),
                ),
              ],
              formGap,
              TextFormField(
                controller: _notes,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'ملاحظات',
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
