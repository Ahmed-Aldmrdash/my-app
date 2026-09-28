import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/models.dart';
import '../utils/ids.dart';
import '../utils/labels.dart';
import '../widgets/common.dart';
import '../widgets/subject_picker.dart';

/// Adds or edits a lecture / section / chapter to study.
class StudyItemForm extends StatefulWidget {
  const StudyItemForm({super.key, this.item, this.initialSubjectId});

  final StudyItem? item;
  final String? initialSubjectId;

  @override
  State<StudyItemForm> createState() => _StudyItemFormState();
}

class _StudyItemFormState extends State<StudyItemForm> {
  final _formKey = GlobalKey<FormState>();
  late String? _subjectId = widget.item?.subjectId ?? widget.initialSubjectId;
  late StudyKind _kind = widget.item?.kind ?? StudyKind.lecture;
  late final _number = TextEditingController(
    text: widget.item?.number?.toString() ?? _suggestedNumber(),
  );
  late final _title = TextEditingController(text: widget.item?.title);
  late final _notes = TextEditingController(text: widget.item?.notes);
  late DateTime _releaseDate = widget.item?.releaseDate ?? DateTime.now();
  late StudyStatus _status = widget.item?.status ?? StudyStatus.notStarted;
  int _addedCount = 0;

  String _suggestedNumber() {
    if (_subjectId == null) return '';
    return context
        .read<AppStore>()
        .nextStudyNumber(_subjectId!, _kind)
        .toString();
  }

  void _refreshSuggestion() {
    if (widget.item == null) _number.text = _suggestedNumber();
  }

  @override
  void dispose() {
    _number.dispose();
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<bool> _save() async {
    if (!_formKey.currentState!.validate()) return false;
    final number = int.tryParse(_number.text.trim());
    final title = _title.text.trim().isNotEmpty
        ? _title.text.trim()
        : '${_kind.label}${number == null ? '' : ' $number'}';
    await context.read<AppStore>().saveStudyItem(
      StudyItem(
        id: widget.item?.id ?? newId(),
        subjectId: _subjectId!,
        kind: _kind,
        title: title,
        number: number,
        releaseDate: _releaseDate,
        status: _status,
        notes: _notes.text.trim(),
        studiedAt: _status.isDone
            ? (widget.item?.studiedAt ?? DateTime.now())
            : null,
      ),
    );
    return true;
  }

  Future<void> _saveAndClose() async {
    if (await _save() && mounted) Navigator.pop(context);
  }

  Future<void> _saveAndNext() async {
    if (!await _save() || !mounted) return;
    setState(() {
      _addedCount++;
      _title.clear();
      _notes.clear();
      _status = StudyStatus.notStarted;
      _number.text = _suggestedNumber();
    });
    showSnack(context, 'اتضافت ✓ — ضيف اللي بعدها');
  }

  Future<void> _delete() async {
    if (!await confirmDelete(context, 'تمسح "${widget.item!.title}"؟')) return;
    if (!mounted) return;
    await context.read<AppStore>().deleteStudyItem(widget.item!.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.item != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          editing
              ? 'تعديل'
              : _addedCount > 0
              ? 'ضفت $_addedCount — ضيف كمان'
              : 'محاضرة نزلت',
        ),
        actions: [
          if (editing)
            IconButton(
              tooltip: 'حذف',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
          TextButton(onPressed: _saveAndClose, child: const Text('حفظ')),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SubjectPicker(
              value: _subjectId,
              onChanged: (v) => setState(() {
                _subjectId = v;
                _refreshSuggestion();
              }),
            ),
            formGap,
            Wrap(
              spacing: 6,
              children: [
                for (final k in StudyKind.values)
                  ChoiceChip(
                    label: Text(k.label),
                    selected: _kind == k,
                    onSelected: (_) => setState(() {
                      _kind = k;
                      _refreshSuggestion();
                    }),
                  ),
              ],
            ),
            formGap,
            Row(
              children: [
                SizedBox(
                  width: 110,
                  child: TextFormField(
                    controller: _number,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'رقمها'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _title,
                    decoration: InputDecoration(
                      labelText: 'العنوان (اختياري)',
                      hintText: 'مثلاً: ${_kind.label} ${_number.text}',
                    ),
                  ),
                ),
              ],
            ),
            formGap,
            DateTimeField(
              label: 'نزلت إمتى',
              value: _releaseDate,
              withTime: false,
              onChanged: (d) =>
                  setState(() => _releaseDate = d ?? _releaseDate),
            ),
            formGap,
            Text('ذاكرتها؟', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: [
                for (final s in StudyStatus.values)
                  ChoiceChip(
                    avatar: Icon(s.icon, color: s.color, size: 18),
                    showCheckmark: false,
                    label: Text(s.label),
                    selected: _status == s,
                    onSelected: (_) => setState(() => _status = s),
                  ),
              ],
            ),
            formGap,
            TextFormField(
              controller: _notes,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'ملاحظات (مثلاً: صفحات، لينك، نقط مهمة)',
                prefixIcon: Icon(Icons.notes),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saveAndClose,
              icon: const Icon(Icons.check),
              label: const Text('حفظ'),
            ),
            if (!editing) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _saveAndNext,
                icon: const Icon(Icons.playlist_add),
                label: const Text('حفظ وإضافة اللي بعدها'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
