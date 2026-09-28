import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/models.dart';
import '../utils/formatters.dart';
import '../utils/ids.dart';
import '../utils/labels.dart';
import '../widgets/common.dart';

/// Adds or edits a subject. Pops with the saved [Subject].
class SubjectForm extends StatefulWidget {
  const SubjectForm({super.key, this.subject});

  final Subject? subject;

  @override
  State<SubjectForm> createState() => _SubjectFormState();
}

class _SubjectFormState extends State<SubjectForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.subject?.name);
  late final _code = TextEditingController(text: widget.subject?.code);
  late final _instructor = TextEditingController(
    text: widget.subject?.instructor,
  );
  late final _assistant = TextEditingController(
    text: widget.subject?.assistant,
  );
  late final _total = TextEditingController(
    text: formatNumber(widget.subject?.totalMarks ?? 100),
  );
  late final _final = TextEditingController(
    text: formatNumber(widget.subject?.finalExamMarks ?? 60),
  );
  late final _notes = TextEditingController(text: widget.subject?.notes);
  late int _color;

  @override
  void initState() {
    super.initState();
    final store = context.read<AppStore>();
    _color =
        widget.subject?.colorValue ??
        subjectPalette[store.subjects.length % subjectPalette.length];
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _code,
      _instructor,
      _assistant,
      _total,
      _final,
      _notes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final subject = Subject(
      id: widget.subject?.id ?? newId(),
      name: _name.text.trim(),
      code: _code.text.trim(),
      instructor: _instructor.text.trim(),
      assistant: _assistant.text.trim(),
      colorValue: _color,
      totalMarks: parseNumber(_total.text) ?? 100,
      finalExamMarks: parseNumber(_final.text) ?? 0,
      notes: _notes.text.trim(),
    );
    await context.read<AppStore>().saveSubject(subject);
    if (mounted) Navigator.pop(context, subject);
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.subject != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'تعديل المادة' : 'مادة جديدة'),
        actions: [TextButton(onPressed: _save, child: const Text('حفظ'))],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              autofocus: !editing,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'اسم المادة',
                hintText: 'مثلاً: برمجة 2',
                prefixIcon: Icon(Icons.menu_book),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'اكتب اسم المادة' : null,
            ),
            formGap,
            TextFormField(
              controller: _code,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'كود المادة (اختياري)',
                prefixIcon: Icon(Icons.tag),
              ),
            ),
            formGap,
            TextFormField(
              controller: _instructor,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'الدكتور',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            formGap,
            TextFormField(
              controller: _assistant,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'المعيد',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            formGap,
            Text('اللون', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final c in subjectPalette)
                  InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => setState(() => _color = c),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: Color(c),
                      child: _color == c
                          ? const Icon(Icons.check, color: Colors.white)
                          : null,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'توزيع الدرجات',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _total,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'الدرجة الكلية',
                    ),
                    validator: (v) {
                      final n = parseNumber(v ?? '');
                      if (n == null || n <= 0) return 'رقم أكبر من صفر';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _final,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'منها للفاينل',
                    ),
                    validator: (v) {
                      final n = parseNumber(v ?? '');
                      final total = parseNumber(_total.text) ?? 0;
                      if (n == null || n < 0) return 'رقم صحيح';
                      if (n > total) return 'أكبر من الكلية';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'الباقي بيبقى أعمال السنة (كويزات، ميدترم، أسايمنتات…)',
                style: Theme.of(context).textTheme.bodySmall,
              ),
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
    );
  }
}
