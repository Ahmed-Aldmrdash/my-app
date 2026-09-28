import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/models.dart';
import '../utils/formatters.dart';
import '../utils/ids.dart';
import '../utils/labels.dart';
import '../widgets/common.dart';
import '../widgets/subject_picker.dart';

/// Adds or edits a weekly timetable slot.
class SessionForm extends StatefulWidget {
  const SessionForm({
    super.key,
    this.session,
    this.initialWeekday,
    this.initialSubjectId,
  });

  final ClassSession? session;
  final int? initialWeekday;
  final String? initialSubjectId;

  @override
  State<SessionForm> createState() => _SessionFormState();
}

class _SessionFormState extends State<SessionForm> {
  final _formKey = GlobalKey<FormState>();
  late String? _subjectId =
      widget.session?.subjectId ?? widget.initialSubjectId;
  late SessionType _type = widget.session?.type ?? SessionType.lecture;
  late int _weekday =
      widget.session?.weekday ??
      widget.initialWeekday ??
      DateTime.now().weekday;
  late int _start = widget.session?.startMinute ?? 9 * 60;
  late int _end = widget.session?.endMinute ?? 11 * 60;
  late final _location = TextEditingController(text: widget.session?.location);
  late final _instructor = TextEditingController(
    text: widget.session?.instructor,
  );
  late bool _notify = widget.session?.notify ?? true;
  late int _reminder =
      widget.session?.reminderMinutes ??
      context.read<AppStore>().settings.defaultClassReminder;
  String? _timeError;

  @override
  void dispose() {
    _location.dispose();
    _instructor.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final valid = _formKey.currentState!.validate();
    setState(
      () =>
          _timeError = _end <= _start ? 'معاد النهاية لازم بعد البداية' : null,
    );
    if (!valid || _timeError != null) return;
    await context.read<AppStore>().saveSession(
      ClassSession(
        id: widget.session?.id ?? newId(),
        subjectId: _subjectId!,
        type: _type,
        weekday: _weekday,
        startMinute: _start,
        endMinute: _end,
        location: _location.text.trim(),
        instructor: _instructor.text.trim(),
        notify: _notify,
        reminderMinutes: _reminder,
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    if (!await confirmDelete(context, 'تمسح الميعاد ده من الجدول؟')) return;
    if (!mounted) return;
    await context.read<AppStore>().deleteSession(widget.session!.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.session != null;
    final reminderChoices = {...classReminderOptions, _reminder}.toList()
      ..sort();
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'تعديل الميعاد' : 'إضافة للجدول'),
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
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SubjectPicker(
              value: _subjectId,
              onChanged: (v) => setState(() => _subjectId = v),
            ),
            formGap,
            SegmentedButton<SessionType>(
              segments: [
                for (final t in SessionType.values)
                  ButtonSegment(
                    value: t,
                    label: Text(t.label),
                    icon: Icon(t.icon),
                  ),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            formGap,
            Text('اليوم', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final d in weekOrder)
                  ChoiceChip(
                    label: Text(weekdayNames[d]!),
                    selected: _weekday == d,
                    onSelected: (_) => setState(() => _weekday = d),
                  ),
              ],
            ),
            formGap,
            Row(
              children: [
                Expanded(
                  child: TimeField(
                    label: 'من',
                    minuteOfDay: _start,
                    onChanged: (m) => setState(() {
                      final length = _end - _start;
                      _start = m;
                      // Keep the same duration when moving the start.
                      if (length > 0) {
                        _end = (m + length).clamp(0, 24 * 60 - 1);
                      }
                    }),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TimeField(
                    label: 'لحد',
                    minuteOfDay: _end,
                    onChanged: (m) => setState(() => _end = m),
                  ),
                ),
              ],
            ),
            if (_timeError != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _timeError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            formGap,
            TextFormField(
              controller: _location,
              decoration: const InputDecoration(
                labelText: 'المكان (مدرج / قاعة / لاب)',
                prefixIcon: Icon(Icons.place_outlined),
              ),
            ),
            formGap,
            TextFormField(
              controller: _instructor,
              decoration: InputDecoration(
                labelText: _type == SessionType.lecture ? 'الدكتور' : 'المعيد',
                prefixIcon: const Icon(Icons.person_outline),
              ),
            ),
            formGap,
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('إشعار قبل الميعاد'),
                    subtitle: const Text('بيتكرر كل أسبوع'),
                    secondary: const Icon(Icons.notifications_active_outlined),
                    value: _notify,
                    onChanged: (v) => setState(() => _notify = v),
                  ),
                  if (_notify)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          for (final m in reminderChoices)
                            ChoiceChip(
                              label: Text(
                                m == 0
                                    ? 'وقت ما تبدأ'
                                    : 'قبلها ${reminderText(m)}',
                              ),
                              selected: _reminder == m,
                              onSelected: (_) => setState(() => _reminder = m),
                            ),
                        ],
                      ),
                    ),
                ],
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
    );
  }
}
