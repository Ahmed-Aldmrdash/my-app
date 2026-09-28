import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/models.dart';
import '../utils/ids.dart';
import '../utils/labels.dart';
import '../widgets/common.dart';
import '../widgets/subject_picker.dart';

class ProjectForm extends StatefulWidget {
  const ProjectForm({super.key, this.project, this.initialSubjectId});

  final Project? project;
  final String? initialSubjectId;

  @override
  State<ProjectForm> createState() => _ProjectFormState();
}

class _ProjectFormState extends State<ProjectForm> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.project?.title);
  late final _description = TextEditingController(
    text: widget.project?.description,
  );
  late final _team = TextEditingController(text: widget.project?.team);
  final _steps = TextEditingController();
  late String? _subjectId =
      widget.project?.subjectId ?? widget.initialSubjectId;
  late DateTime? _deadline = widget.project?.deadline;
  late List<int> _reminders = [
    ...(widget.project?.reminders ?? const [3 * 24 * 60, 24 * 60]),
  ];

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _team.dispose();
    _steps.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final old = widget.project;
    final newSteps = _steps.text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .map((l) => ProjectStep(id: newId(), title: l));
    final project = Project(
      id: old?.id ?? newId(),
      title: _title.text.trim(),
      subjectId: _subjectId,
      description: _description.text.trim(),
      team: _team.text.trim(),
      deadline: _deadline,
      steps: [...?old?.steps, ...newSteps],
      manualProgress: old?.manualProgress ?? 0,
      submitted: old?.submitted ?? false,
      reminders: _reminders,
    );
    await context.read<AppStore>().saveProject(project);
    if (mounted) Navigator.pop(context, project);
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.project != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'تعديل المشروع' : 'مشروع جديد'),
        actions: [TextButton(onPressed: _save, child: const Text('حفظ'))],
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
                labelText: 'اسم المشروع',
                prefixIcon: Icon(Icons.rocket_launch_outlined),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'اكتب اسم المشروع' : null,
            ),
            formGap,
            SubjectPicker(
              value: _subjectId,
              required: false,
              onChanged: (v) => setState(() => _subjectId = v),
            ),
            formGap,
            TextFormField(
              controller: _description,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'فكرته / المطلوب',
                prefixIcon: Icon(Icons.notes),
              ),
            ),
            formGap,
            TextFormField(
              controller: _team,
              decoration: const InputDecoration(
                labelText: 'التيم (اختياري)',
                prefixIcon: Icon(Icons.groups_outlined),
              ),
            ),
            formGap,
            DateTimeField(
              label: 'معاد التسليم',
              value: _deadline,
              clearable: true,
              onChanged: (d) => setState(() => _deadline = d),
            ),
            if (_deadline != null) ...[
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
            formGap,
            TextFormField(
              controller: _steps,
              minLines: 3,
              maxLines: 8,
              decoration: InputDecoration(
                labelText: editing
                    ? 'ضيف مراحل جديدة (كل مرحلة في سطر)'
                    : 'مراحل المشروع (كل مرحلة في سطر)',
                hintText: 'تحديد المتطلبات\nالتصميم\nالبرمجة\nالتسليم',
                alignLabelWithHint: true,
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
