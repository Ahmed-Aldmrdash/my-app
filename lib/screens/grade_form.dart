import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/models.dart';
import '../utils/formatters.dart';
import '../utils/ids.dart';
import '../utils/labels.dart';
import '../widgets/common.dart';
import '../widgets/subject_picker.dart';

/// Records a mark: what it was for, the score, out of what, when, and
/// whether it is a bonus.
class GradeForm extends StatefulWidget {
  const GradeForm({super.key, this.grade, this.initialSubjectId});

  final GradeEntry? grade;
  final String? initialSubjectId;

  @override
  State<GradeForm> createState() => _GradeFormState();
}

class _GradeFormState extends State<GradeForm> {
  final _formKey = GlobalKey<FormState>();
  late String? _subjectId = widget.grade?.subjectId ?? widget.initialSubjectId;
  late GradeCategory _category = widget.grade?.category ?? GradeCategory.quiz;
  late final _title = TextEditingController(text: widget.grade?.title);
  late final _score = TextEditingController(
    text: widget.grade == null ? '' : formatNumber(widget.grade!.score),
  );
  late final _max = TextEditingController(
    text: widget.grade == null || widget.grade!.maxScore == 0
        ? ''
        : formatNumber(widget.grade!.maxScore),
  );
  late final _notes = TextEditingController(text: widget.grade?.notes);
  late DateTime _date = widget.grade?.date ?? DateTime.now();
  late bool _bonus = widget.grade?.isBonus ?? false;

  @override
  void dispose() {
    _title.dispose();
    _score.dispose();
    _max.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final title = _title.text.trim().isEmpty
        ? _category.label
        : _title.text.trim();
    await context.read<AppStore>().saveGrade(
      GradeEntry(
        id: widget.grade?.id ?? newId(),
        subjectId: _subjectId!,
        category: _category,
        title: title,
        score: parseNumber(_score.text)!,
        maxScore: parseNumber(_max.text) ?? 0,
        date: _date,
        isBonus: _bonus,
        notes: _notes.text.trim(),
        assessmentId: widget.grade?.assessmentId,
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    if (!await confirmDelete(context, 'تمسح الدرجة دي؟')) return;
    if (!mounted) return;
    await context.read<AppStore>().deleteGrade(widget.grade!.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.grade != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'تعديل الدرجة' : 'درجة جديدة'),
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
            Text(
              'الدرجة دي من إيه؟',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final c in GradeCategory.values)
                  ChoiceChip(
                    avatar: Icon(c.icon, size: 18),
                    showCheckmark: false,
                    label: Text(c.label),
                    selected: _category == c,
                    onSelected: (_) => setState(() => _category = c),
                  ),
              ],
            ),
            formGap,
            TextFormField(
              controller: _title,
              decoration: InputDecoration(
                labelText: 'اسمها',
                hintText: 'مثلاً: ${_category.label} 2',
                prefixIcon: const Icon(Icons.label_outline),
              ),
            ),
            formGap,
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.star_outline),
              title: const Text('دي درجات بونص'),
              subtitle: const Text(
                'بتزود مجموعك من غير ما تزود النهاية العظمى',
              ),
              value: _bonus,
              onChanged: (v) => setState(() => _bonus = v),
            ),
            formGap,
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _score,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: _bonus ? 'كام درجة بونص' : 'خدت كام',
                    ),
                    validator: (v) {
                      final n = parseNumber(v ?? '');
                      if (n == null || n < 0) return 'اكتب رقم';
                      final max = parseNumber(_max.text);
                      if (!_bonus && max != null && n > max) {
                        return 'أكبر من النهاية';
                      }
                      return null;
                    },
                  ),
                ),
                if (!_bonus) ...[
                  const Padding(
                    padding: EdgeInsets.only(top: 18, left: 10, right: 10),
                    child: Text('من'),
                  ),
                  Expanded(
                    child: TextFormField(
                      controller: _max,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'من كام'),
                      validator: (v) {
                        if (_bonus) return null;
                        final n = parseNumber(v ?? '');
                        if (n == null || n <= 0) return 'اكتب رقم';
                        return null;
                      },
                    ),
                  ),
                ],
              ],
            ),
            formGap,
            DateTimeField(
              label: 'خدتها إمتى',
              value: _date,
              withTime: false,
              onChanged: (d) => setState(() => _date = d ?? _date),
            ),
            formGap,
            TextFormField(
              controller: _notes,
              maxLines: 2,
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
    );
  }
}
