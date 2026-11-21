import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/ids.dart';
import '../utils/labels.dart';
import '../widgets/common.dart';

extension CalendarKindLabel on CalendarKind {
  String get label => switch (this) {
    CalendarKind.holiday => 'إجازة',
    CalendarKind.registration => 'تسجيل مواد',
    CalendarKind.addDrop => 'حذف وإضافة',
    CalendarKind.exams => 'امتحانات',
    CalendarKind.semester => 'بداية / نهاية ترم',
    CalendarKind.other => 'حاجة تانية',
  };

  IconData get icon => switch (this) {
    CalendarKind.holiday => Icons.beach_access_rounded,
    CalendarKind.registration => Icons.how_to_reg_rounded,
    CalendarKind.addDrop => Icons.swap_horiz_rounded,
    CalendarKind.exams => Icons.edit_note_rounded,
    CalendarKind.semester => Icons.flag_rounded,
    CalendarKind.other => Icons.event_rounded,
  };

  Color get color => switch (this) {
    CalendarKind.holiday => AppColors.teal,
    CalendarKind.registration => AppColors.sky,
    CalendarKind.addDrop => AppColors.orange,
    CalendarKind.exams => AppColors.coral,
    CalendarKind.semester => AppColors.primary,
    CalendarKind.other => AppColors.bonus,
  };
}

/// "15 ديسمبر" or "15 – 20 ديسمبر" for a period.
String eventDates(CalendarEvent e) {
  if (e.end == null || e.lastDay == e.firstDay) {
    return formatLongDate(e.firstDay);
  }
  return '${formatShortDate(e.firstDay)} ← ${formatShortDate(e.lastDay)}';
}

/// The academic calendar: holidays, registration, exam periods…
class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final now = DateTime.now();
    final events = store.calendarSorted;
    final upcoming = events.where((e) => !e.isOver(now)).toList();
    final past = events.where((e) => e.isOver(now)).toList().reversed.toList();
    return Scaffold(
      appBar: AppBar(title: const Text('التقويم الأكاديمي')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'calendar-fab',
        onPressed: () => pushPage(context, const CalendarEventForm()),
        icon: const Icon(Icons.add_rounded),
        label: const Text('ميعاد جديد'),
      ),
      body: events.isEmpty
          ? const EmptyState(
              icon: Icons.event_available_rounded,
              title: 'ضيف مواعيد الكلية',
              message:
                  'الإجازات، التسجيل، الحذف والإضافة، بداية الامتحانات… '
                  'والإجازة اللي مفيهاش محاضرات بتقفل تذكيرات الجدول في أيامها',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
              children: [
                if (upcoming.isNotEmpty) ...[
                  const SectionHeader('الجاية', icon: Icons.upcoming_rounded),
                  for (final e in upcoming) _EventTile(event: e, now: now),
                ],
                if (past.isNotEmpty) ...[
                  const SectionHeader('عدّت', icon: Icons.history_rounded),
                  for (final e in past)
                    Opacity(
                      opacity: 0.6,
                      child: _EventTile(event: e, now: now),
                    ),
                ],
              ],
            ),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event, required this.now});

  final CalendarEvent event;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final happening = event.covers(now);
    return AppCard(
      onTap: () => pushPage(context, CalendarEventForm(event: event)),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          IconBadge(event.kind.icon, color: event.kind.color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(eventDates(event), style: theme.textTheme.bodySmall),
                if (event.noClasses)
                  Text(
                    'مفيش محاضرات',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.teal,
                    ),
                  ),
              ],
            ),
          ),
          if (happening)
            const Pill('دلوقتي', color: AppColors.teal)
          else if (!event.isOver(now))
            Pill(friendlyDay(event.firstDay, now), color: event.kind.color),
        ],
      ),
    );
  }
}

/// Adds or edits a date on the academic calendar.
class CalendarEventForm extends StatefulWidget {
  const CalendarEventForm({super.key, this.event});

  final CalendarEvent? event;

  @override
  State<CalendarEventForm> createState() => _CalendarEventFormState();
}

class _CalendarEventFormState extends State<CalendarEventForm> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.event?.title);
  late final _notes = TextEditingController(text: widget.event?.notes);
  late CalendarKind _kind = widget.event?.kind ?? CalendarKind.holiday;
  late DateTime? _start = widget.event?.firstDay;
  late DateTime? _end = widget.event?.end == null
      ? null
      : widget.event!.lastDay;
  late bool _noClasses = widget.event?.noClasses ?? true;
  late List<int> _reminders = [
    ...(widget.event?.reminders ?? const [24 * 60]),
  ];

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_start == null) {
      showSnack(context, 'اختار اليوم');
      return;
    }
    final end = _end;
    await context.read<AppStore>().saveEvent(
      CalendarEvent(
        id: widget.event?.id ?? newId(),
        title: _title.text.trim(),
        kind: _kind,
        start: _start!,
        end: end == null || !end.isAfter(_start!) ? null : end,
        noClasses: _noClasses,
        reminders: _reminders,
        notes: _notes.text.trim(),
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    if (!await confirmDelete(context, 'تمسح الميعاد ده؟')) return;
    if (!mounted) return;
    await context.read<AppStore>().deleteEvent(widget.event!.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.event != null;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'تعديل الميعاد' : 'ميعاد جديد'),
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
                  for (final k in CalendarKind.values)
                    ChoiceChip(
                      avatar: Icon(k.icon, size: 18, color: k.color),
                      label: Text(k.label),
                      selected: _kind == k,
                      onSelected: (_) => setState(() {
                        _kind = k;
                        _noClasses = k == CalendarKind.holiday;
                      }),
                    ),
                ],
              ),
              formGap,
              TextFormField(
                controller: _title,
                autofocus: !editing,
                decoration: const InputDecoration(
                  labelText: 'إيه هو؟',
                  hintText: 'مثلاً: إجازة نص السنة',
                  prefixIcon: Icon(Icons.title_rounded),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'اكتب اسمه' : null,
              ),
              formGap,
              DateTimeField(
                label: 'من يوم',
                value: _start,
                withTime: false,
                onChanged: (d) => setState(() => _start = d),
              ),
              formGap,
              DateTimeField(
                label: 'لحد يوم (لو فترة)',
                value: _end,
                withTime: false,
                clearable: true,
                onChanged: (d) => setState(() => _end = d),
              ),
              formGap,
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _noClasses,
                onChanged: (v) => setState(() => _noClasses = v),
                title: const Text('مفيش محاضرات في الأيام دي'),
                subtitle: const Text('تذكيرات الجدول والحضور بتقف فيها'),
              ),
              formGap,
              Text('فكرني قبلها بـ', style: theme.textTheme.labelLarge),
              const SizedBox(height: 6),
              ReminderChips(
                options: deadlineReminderOptions,
                selected: _reminders,
                onChanged: (v) => setState(() => _reminders = v),
              ),
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
