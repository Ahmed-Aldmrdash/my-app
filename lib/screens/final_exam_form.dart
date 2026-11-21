import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/models.dart';
import '../utils/formatters.dart';
import '../utils/ids.dart';
import '../utils/labels.dart';
import '../widgets/common.dart';
import '../widgets/subject_picker.dart';

/// Adds or edits a final exam.
class FinalExamForm extends StatefulWidget {
  const FinalExamForm({super.key, this.exam, this.initialSubjectId});

  final FinalExam? exam;
  final String? initialSubjectId;

  @override
  State<FinalExamForm> createState() => _FinalExamFormState();
}

class _FinalExamFormState extends State<FinalExamForm> {
  final _formKey = GlobalKey<FormState>();
  late String? _subjectId = widget.exam?.subjectId ?? widget.initialSubjectId;
  late DateTime? _start = widget.exam?.start;
  late int _duration = widget.exam?.durationMinutes ?? 120;
  late final _place = TextEditingController(text: widget.exam?.place);
  late final _seat = TextEditingController(text: widget.exam?.seat);
  late final _notes = TextEditingController(text: widget.exam?.notes);
  late List<int> _reminders = [
    ...(widget.exam?.reminders ?? const [24 * 60, 3 * 60]),
  ];

  static const _durations = [60, 90, 120, 150, 180];

  @override
  void dispose() {
    _place.dispose();
    _seat.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_subjectId == null) {
      showSnack(context, 'اختار المادة');
      return;
    }
    if (_start == null) {
      showSnack(context, 'اختار ميعاد الامتحان');
      return;
    }
    await context.read<AppStore>().saveFinal(
      FinalExam(
        id: widget.exam?.id ?? newId(),
        subjectId: _subjectId!,
        start: _start!,
        durationMinutes: _duration,
        place: _place.text.trim(),
        seat: _seat.text.trim(),
        notes: _notes.text.trim(),
        reminders: _reminders,
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    if (!await confirmDelete(context, 'تمسح الامتحان ده؟')) return;
    if (!mounted) return;
    await context.read<AppStore>().deleteFinal(widget.exam!.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.exam != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'تعديل الامتحان' : 'امتحان فاينال'),
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
              SubjectPicker(
                value: _subjectId,
                onChanged: (v) => setState(() => _subjectId = v),
              ),
              formGap,
              DateTimeField(
                label: 'الامتحان إمتى؟',
                value: _start,
                onChanged: (d) => setState(() => _start = d),
              ),
              formGap,
              Text(
                'مدة الامتحان',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final d in _durations)
                    ChoiceChip(
                      label: Text(durationText(Duration(minutes: d))),
                      selected: _duration == d,
                      onSelected: (_) => setState(() => _duration = d),
                    ),
                ],
              ),
              formGap,
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _place,
                      decoration: const InputDecoration(
                        labelText: 'اللجنة / المكان',
                        prefixIcon: Icon(Icons.place_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _seat,
                      decoration: const InputDecoration(
                        labelText: 'رقم الجلوس',
                        prefixIcon: Icon(Icons.event_seat_outlined),
                      ),
                    ),
                  ),
                ],
              ),
              formGap,
              TextFormField(
                controller: _notes,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'ملاحظات (المقرر، المسموح بيه…)',
                  prefixIcon: Icon(Icons.notes),
                ),
              ),
              formGap,
              Text(
                'فكرني قبلها بـ',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 6),
              ReminderChips(
                options: deadlineReminderOptions,
                selected: _reminders,
                onChanged: (v) => setState(() => _reminders = v),
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

/// Adds or edits one entry of the study plan.
class PlanEntryForm extends StatefulWidget {
  const PlanEntryForm({super.key, this.entry, this.initialDay});

  final PlanEntry? entry;
  final DateTime? initialDay;

  @override
  State<PlanEntryForm> createState() => _PlanEntryFormState();
}

class _PlanEntryFormState extends State<PlanEntryForm> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.entry?.title);
  late DateTime _day =
      widget.entry?.day ?? dateOnly(widget.initialDay ?? DateTime.now());
  late String? _subjectId = widget.entry?.subjectId;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final old = widget.entry;
    final store = context.read<AppStore>();
    if (old == null) {
      await store.savePlanEntry(
        PlanEntry(
          id: newId(),
          day: _day,
          title: _title.text.trim(),
          subjectId: _subjectId,
        ),
      );
    } else {
      // Edited by hand: the automatic planner leaves it alone from now on.
      await store.savePlanEntry(
        old.copyWith(
          day: _day,
          title: _title.text.trim(),
          subjectId: _subjectId,
          clearSubject: _subjectId == null,
          auto: false,
        ),
      );
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    if (!await confirmDelete(context, 'تمسح المهمة دي من الخطة؟')) return;
    if (!mounted) return;
    await context.read<AppStore>().deletePlanEntry(widget.entry!.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.entry != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'تعديل المهمة' : 'مهمة في الخطة'),
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
                controller: _title,
                autofocus: !editing,
                decoration: const InputDecoration(
                  labelText: 'هتعمل إيه؟',
                  prefixIcon: Icon(Icons.edit_note_rounded),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'اكتب المهمة' : null,
              ),
              formGap,
              DateTimeField(
                label: 'يوم',
                value: _day,
                withTime: false,
                onChanged: (d) => setState(() => _day = d ?? _day),
              ),
              formGap,
              SubjectPicker(
                value: _subjectId,
                required: false,
                onChanged: (v) => setState(() => _subjectId = v),
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
