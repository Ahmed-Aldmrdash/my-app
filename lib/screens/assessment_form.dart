import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/models.dart';
import '../utils/ids.dart';
import '../utils/labels.dart';
import '../widgets/common.dart';
import '../widgets/subject_picker.dart';

/// Adds or edits a quiz, exam or assignment.
class AssessmentForm extends StatefulWidget {
  const AssessmentForm({
    super.key,
    this.assessment,
    this.initialType = AssessmentType.quiz,
    this.initialSubjectId,
  });

  final Assessment? assessment;
  final AssessmentType initialType;
  final String? initialSubjectId;

  @override
  State<AssessmentForm> createState() => _AssessmentFormState();
}

class _AssessmentFormState extends State<AssessmentForm> {
  final _formKey = GlobalKey<FormState>();
  late AssessmentType _type = widget.assessment?.type ?? widget.initialType;
  late String? _subjectId =
      widget.assessment?.subjectId ?? widget.initialSubjectId;
  late final _title = TextEditingController(text: widget.assessment?.title);
  late final _location = TextEditingController(
    text: widget.assessment?.location,
  );
  late final _notes = TextEditingController(text: widget.assessment?.notes);
  late DateTime? _due = widget.assessment?.dueDate;
  late List<int> _reminders = [
    ...(widget.assessment?.reminders ?? const [24 * 60, 60]),
  ];
  late bool _done = widget.assessment?.done ?? false;
  String? _dueError;

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final valid = _formKey.currentState!.validate();
    setState(() => _dueError = _due == null ? 'حدد المعاد' : null);
    if (!valid || _due == null) return;
    final old = widget.assessment;
    await context.read<AppStore>().saveAssessment(
      Assessment(
        id: old?.id ?? newId(),
        subjectId: _subjectId!,
        type: _type,
        title: _title.text.trim(),
        dueDate: _due!,
        location: _location.text.trim(),
        notes: _notes.text.trim(),
        done: _done,
        completedAt: _done ? (old?.completedAt ?? DateTime.now()) : null,
        reminders: _reminders,
        gradeId: old?.gradeId,
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    if (!await confirmDelete(
      context,
      'تمسح ${_type.label} "${widget.assessment!.title}"؟',
      message: 'الدرجة المتسجلة ليه (لو فيه) هتفضل في درجات المادة.',
    )) {
      return;
    }
    if (!mounted) return;
    await context.read<AppStore>().deleteAssessment(widget.assessment!.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.assessment != null;
    final isAssignment = _type == AssessmentType.assignment;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'تعديل ${_type.label}' : '${_type.label} جديد'),
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
            SegmentedButton<AssessmentType>(
              segments: [
                for (final t in AssessmentType.values)
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
            SubjectPicker(
              value: _subjectId,
              onChanged: (v) => setState(() => _subjectId = v),
            ),
            formGap,
            TextFormField(
              controller: _title,
              decoration: InputDecoration(
                labelText: 'العنوان',
                hintText: switch (_type) {
                  AssessmentType.quiz => 'مثلاً: كويز 2 (شابتر 3 و 4)',
                  AssessmentType.exam => 'مثلاً: ميدترم',
                  AssessmentType.assignment => 'مثلاً: شيت 3',
                },
                prefixIcon: Icon(_type.icon),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'اكتب العنوان' : null,
            ),
            formGap,
            DateTimeField(
              label: isAssignment ? 'آخر معاد للتسليم' : 'المعاد',
              value: _due,
              onChanged: (d) => setState(() {
                _due = d;
                _dueError = null;
              }),
            ),
            if (_dueError != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _dueError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            formGap,
            TextFormField(
              controller: _location,
              decoration: InputDecoration(
                labelText: isAssignment
                    ? 'هيتسلم فين (إيميل، موقع، ورقي…)'
                    : 'المكان',
                prefixIcon: const Icon(Icons.place_outlined),
              ),
            ),
            formGap,
            TextFormField(
              controller: _notes,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'ملاحظات (المنهج، المطلوب…)',
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
            if (editing) ...[
              formGap,
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_type.doneLabel),
                value: _done,
                onChanged: (v) => setState(() => _done = v),
              ),
            ],
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
