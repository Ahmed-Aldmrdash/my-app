import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/models.dart';
import '../screens/subject_form.dart';
import 'common.dart';

const _addNew = '__add_new__';

/// Dropdown of subjects with an option to create a new one on the spot.
class SubjectPicker extends StatefulWidget {
  const SubjectPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.required = true,
  });

  final String? value;
  final ValueChanged<String?> onChanged;

  /// When false, a "بدون مادة" option is offered.
  final bool required;

  @override
  State<SubjectPicker> createState() => _SubjectPickerState();
}

class _SubjectPickerState extends State<SubjectPicker> {
  // Bumped to rebuild the dropdown after the "new subject" flow, so it
  // never stays on the "مادة جديدة…" entry.
  int _version = 0;

  Future<void> _addSubject() async {
    final created = await pushPage<Subject>(context, const SubjectForm());
    if (!mounted) return;
    setState(() => _version++);
    widget.onChanged(created?.id ?? widget.value);
  }

  @override
  Widget build(BuildContext context) {
    final subjects = context.watch<AppStore>().subjects;
    final exists = subjects.any((s) => s.id == widget.value);
    final value = exists ? widget.value : null;
    return DropdownButtonFormField<String?>(
      key: ValueKey('$value/$_version'),
      initialValue: value,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'المادة',
        prefixIcon: Icon(Icons.menu_book),
      ),
      validator: widget.required
          ? (v) => (v == null || v == _addNew) ? 'اختار المادة' : null
          : null,
      items: [
        if (!widget.required)
          const DropdownMenuItem<String?>(
            value: null,
            child: Text('بدون مادة'),
          ),
        for (final Subject s in subjects)
          DropdownMenuItem<String?>(
            value: s.id,
            child: Row(
              children: [
                CircleAvatar(radius: 6, backgroundColor: Color(s.colorValue)),
                const SizedBox(width: 10),
                Expanded(child: Text(s.name, overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
        const DropdownMenuItem<String?>(
          value: _addNew,
          child: Row(
            children: [
              Icon(Icons.add, size: 18),
              SizedBox(width: 8),
              Text('مادة جديدة…'),
            ],
          ),
        ),
      ],
      onChanged: (v) {
        if (v == _addNew) {
          _addSubject();
        } else {
          widget.onChanged(v);
        }
      },
    );
  }
}
