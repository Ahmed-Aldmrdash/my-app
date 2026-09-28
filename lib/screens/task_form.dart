import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/models.dart';
import '../utils/ids.dart';
import '../utils/labels.dart';
import '../widgets/common.dart';
import '../widgets/subject_picker.dart';

class TaskForm extends StatefulWidget {
  const TaskForm({super.key, this.task});

  final TaskItem? task;

  @override
  State<TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends State<TaskForm> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.task?.title);
  late final _notes = TextEditingController(text: widget.task?.notes);
  late String? _subjectId = widget.task?.subjectId;
  late DateTime? _due = widget.task?.dueDate;
  late Priority _priority = widget.task?.priority ?? Priority.medium;
  late List<int> _reminders = [
    ...(widget.task?.reminders ?? const [60]),
  ];

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final old = widget.task;
    await context.read<AppStore>().saveTask(
      TaskItem(
        id: old?.id ?? newId(),
        title: _title.text.trim(),
        notes: _notes.text.trim(),
        subjectId: _subjectId,
        dueDate: _due,
        priority: _priority,
        done: old?.done ?? false,
        completedAt: old?.completedAt,
        reminders: _reminders,
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    if (!await confirmDelete(context, 'تمسح التاسك ده؟')) return;
    if (!mounted) return;
    await context.read<AppStore>().deleteTask(widget.task!.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.task != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'تعديل التاسك' : 'تاسك جديد'),
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
            TextFormField(
              controller: _title,
              autofocus: !editing,
              decoration: const InputDecoration(
                labelText: 'عايز تعمل إيه؟',
                prefixIcon: Icon(Icons.check_circle_outline),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'اكتب التاسك' : null,
            ),
            formGap,
            TextFormField(
              controller: _notes,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'تفاصيل',
                prefixIcon: Icon(Icons.notes),
              ),
            ),
            formGap,
            SubjectPicker(
              value: _subjectId,
              required: false,
              onChanged: (v) => setState(() => _subjectId = v),
            ),
            formGap,
            Text('الأهمية', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            SegmentedButton<Priority>(
              segments: [
                for (final p in Priority.values)
                  ButtonSegment(
                    value: p,
                    label: Text(p.label),
                    icon: Icon(Icons.flag, color: p.color),
                  ),
              ],
              selected: {_priority},
              onSelectionChanged: (s) => setState(() => _priority = s.first),
            ),
            formGap,
            DateTimeField(
              label: 'لازم يخلص إمتى (اختياري)',
              value: _due,
              clearable: true,
              onChanged: (d) => setState(() => _due = d),
            ),
            if (_due != null) ...[
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
