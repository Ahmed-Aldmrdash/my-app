import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/models.dart';
import '../utils/formatters.dart';
import '../utils/ids.dart';
import '../widgets/common.dart';
import 'project_form.dart';

/// Shows how far a project has got and lets the student tick off steps.
class ProjectDetailScreen extends StatefulWidget {
  const ProjectDetailScreen({super.key, required this.projectId});

  final String projectId;

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  final _newStep = TextEditingController();

  @override
  void dispose() {
    _newStep.dispose();
    super.dispose();
  }

  Future<void> _addStep(AppStore store, Project p) async {
    final title = _newStep.text.trim();
    if (title.isEmpty) return;
    _newStep.clear();
    await store.updateProjectSteps(p.id, [
      ...p.steps,
      ProjectStep(id: newId(), title: title),
    ]);
  }

  Future<void> _renameStep(AppStore store, Project p, ProjectStep step) async {
    final controller = TextEditingController(text: step.title);
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تعديل المرحلة'),
        content: TextField(controller: controller, autofocus: true),
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
    );
    controller.dispose();
    if (title == null || title.isEmpty) return;
    await store.updateProjectSteps(p.id, [
      for (final s in p.steps) s.id == step.id ? s.copyWith(title: title) : s,
    ]);
  }

  Future<void> _delete(AppStore store, Project p) async {
    if (!await confirmDelete(context, 'تمسح مشروع "${p.title}"؟')) return;
    await store.deleteProject(p.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final p = store.projectById(widget.projectId);
    if (p == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
          icon: Icons.delete_outline,
          title: 'المشروع ده اتمسح',
        ),
      );
    }
    final theme = Theme.of(context);
    final subject = store.subjectById(p.subjectId);
    final color = subject == null
        ? theme.colorScheme.primary
        : Color(subject.colorValue);
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: Text(p.title),
        actions: [
          IconButton(
            tooltip: 'تعديل',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => pushPage(context, ProjectForm(project: p)),
          ),
          IconButton(
            tooltip: 'حذف',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(store, p),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${(p.progress * 100).round()}%',
                        style: theme.textTheme.displaySmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          p.submitted
                              ? 'اتسلّم 🎉'
                              : p.steps.isEmpty
                              ? 'وصلت لحد هنا'
                              : 'خلصت ${p.doneSteps} من ${p.steps.length} مراحل',
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  RoundedProgress(value: p.progress, color: color, height: 12),
                  if (p.steps.isEmpty && !p.submitted) ...[
                    const SizedBox(height: 8),
                    Slider(
                      value: p.manualProgress.toDouble(),
                      max: 100,
                      divisions: 20,
                      label: '${p.manualProgress}%',
                      onChanged: (v) => store.saveProject(
                        p.copyWith(manualProgress: v.round()),
                      ),
                    ),
                    Text(
                      'حرك الشريط، أو ضيف مراحل تحت عشان النسبة تتحسب لوحدها',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                if (subject != null)
                  ListTile(
                    leading: Icon(Icons.menu_book, color: color),
                    title: Text(subject.name),
                  ),
                if (p.deadline != null)
                  ListTile(
                    leading: const Icon(Icons.event),
                    title: Text(
                      '${formatLongDate(p.deadline!)} • ${formatTime(p.deadline!)}',
                    ),
                    trailing: p.submitted
                        ? null
                        : ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 124),
                            child: CountdownPill(due: p.deadline!, now: now),
                          ),
                  ),
                if (p.team.isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.groups_outlined),
                    title: Text(p.team),
                  ),
                if (p.description.isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.notes),
                    title: Text(p.description),
                  ),
                SwitchListTile(
                  secondary: const Icon(Icons.task_alt),
                  title: const Text('سلمت المشروع'),
                  value: p.submitted,
                  onChanged: (v) => store.saveProject(p.copyWith(submitted: v)),
                ),
              ],
            ),
          ),
          const SectionHeader(
            'المراحل',
            padding: EdgeInsetsDirectional.fromSTEB(4, 20, 4, 6),
          ),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                for (final step in p.steps)
                  Dismissible(
                    key: ValueKey(step.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: theme.colorScheme.errorContainer,
                      alignment: AlignmentDirectional.centerEnd,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: const Icon(Icons.delete_outline),
                    ),
                    onDismissed: (_) {
                      final before = p.steps;
                      store.updateProjectSteps(p.id, [
                        for (final s in p.steps)
                          if (s.id != step.id) s,
                      ]);
                      showSnack(
                        context,
                        'اتمسحت "${step.title}"',
                        onUndo: () => store.updateProjectSteps(p.id, before),
                      );
                    },
                    child: CheckboxListTile(
                      controlAffinity: ListTileControlAffinity.leading,
                      value: step.done,
                      title: GestureDetector(
                        onLongPress: () => _renameStep(store, p, step),
                        child: Text(
                          step.title,
                          style: step.done
                              ? const TextStyle(
                                  decoration: TextDecoration.lineThrough,
                                )
                              : null,
                        ),
                      ),
                      onChanged: (v) => store.updateProjectSteps(p.id, [
                        for (final s in p.steps)
                          s.id == step.id ? s.copyWith(done: v ?? false) : s,
                      ]),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 4, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _newStep,
                          decoration: const InputDecoration(
                            hintText: 'مرحلة جديدة…',
                            border: InputBorder.none,
                            filled: false,
                          ),
                          onSubmitted: (_) => _addStep(store, p),
                        ),
                      ),
                      IconButton(
                        tooltip: 'إضافة',
                        icon: const Icon(Icons.add_circle),
                        color: color,
                        onPressed: () => _addStep(store, p),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (p.steps.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                'اسحب المرحلة عشان تمسحها، ودوس عليها كتير عشان تعدل اسمها',
                style: theme.textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}
