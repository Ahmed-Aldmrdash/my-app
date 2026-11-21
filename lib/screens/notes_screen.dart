import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/app_store.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/ids.dart';
import '../widgets/common.dart';
import '../widgets/subject_picker.dart';

/// Opens [url] in the browser or the app that handles it (YouTube, Drive…).
Future<void> openLink(BuildContext context, String url) async {
  final uri = Uri.tryParse(normalizeUrl(url));
  var ok = false;
  if (uri != null) {
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      ok = false;
    }
  }
  if (!ok && context.mounted) showSnack(context, 'مش قادر أفتح اللينك ده');
}

IconData linkIcon(Note n) {
  if (!n.isLink) return Icons.sticky_note_2_rounded;
  return switch (linkTypeOf(n.url)) {
    LinkType.youtube => Icons.smart_display_rounded,
    LinkType.drive => Icons.add_to_drive_rounded,
    LinkType.pdf => Icons.picture_as_pdf_rounded,
    LinkType.web => Icons.link_rounded,
  };
}

Color linkColor(Note n) {
  if (!n.isLink) return AppColors.amber;
  return switch (linkTypeOf(n.url)) {
    LinkType.youtube => const Color(0xFFE53935),
    LinkType.drive => AppColors.teal,
    LinkType.pdf => AppColors.coral,
    LinkType.web => AppColors.sky,
  };
}

/// Notes and links: all of them, or just one subject's or one lecture's.
class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key, this.subjectId, this.studyItemId});

  final String? subjectId;
  final String? studyItemId;

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final _search = TextEditingController();
  late String? _subjectFilter = widget.subjectId;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final lecture = widget.studyItemId == null
        ? null
        : store.studyItems.where((s) => s.id == widget.studyItemId).firstOrNull;
    final query = _search.text.trim();
    final notes = store
        .notesFor(subjectId: _subjectFilter, studyItemId: widget.studyItemId)
        .where(
          (n) =>
              query.isEmpty ||
              n.title.contains(query) ||
              n.body.contains(query) ||
              n.url.contains(query),
        )
        .toList();
    final fixedSubject = widget.subjectId != null || widget.studyItemId != null;
    final title = lecture != null
        ? 'ملاحظات ${lecture.title}'
        : widget.subjectId != null
        ? 'ملاحظات ${store.subjectById(widget.subjectId)?.name ?? ''}'
        : 'الملاحظات واللينكات';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'notes-fab',
        onPressed: () => pushPage(
          context,
          NoteForm(
            initialSubjectId: lecture?.subjectId ?? _subjectFilter,
            initialStudyItemId: widget.studyItemId,
          ),
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('ملاحظة أو لينك'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
        children: [
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'دوّر في ملاحظاتك',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          if (!fixedSubject && store.subjects.isNotEmpty) ...[
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('الكل'),
                    selected: _subjectFilter == null,
                    onSelected: (_) => setState(() => _subjectFilter = null),
                  ),
                  for (final s in store.subjects) ...[
                    const SizedBox(width: 6),
                    ChoiceChip(
                      label: Text(s.name),
                      selected: _subjectFilter == s.id,
                      onSelected: (_) => setState(() => _subjectFilter = s.id),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 6),
          if (notes.isEmpty)
            EmptyState(
              icon: Icons.sticky_note_2_rounded,
              color: AppColors.amber,
              title: query.isEmpty ? 'لسه مفيش ملاحظات' : 'مفيش نتايج',
              message: query.isEmpty
                  ? 'اكتب ملاحظاتك، أو احفظ لينكات الدرايف واليوتيوب والـ PDF '
                        'بتاعة كل مادة ومحاضرة في مكان واحد'
                  : null,
            )
          else
            for (final n in notes) NoteTile(note: n),
        ],
      ),
    );
  }
}

/// A note or link as a card: tap to edit, the open button opens the link.
class NoteTile extends StatelessWidget {
  const NoteTile({super.key, required this.note, this.showSubject = true});

  final Note note;
  final bool showSubject;

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final theme = Theme.of(context);
    final subject = store.subjectById(note.subjectId);
    final lecture = note.studyItemId == null
        ? null
        : store.studyItems.where((s) => s.id == note.studyItemId).firstOrNull;
    final preview = note.body.isNotEmpty
        ? note.body
        : note.isLink
        ? Uri.tryParse(normalizeUrl(note.url))?.host ?? note.url
        : '';
    return AppCard(
      onTap: () => pushPage(context, NoteForm(note: note)),
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge(linkIcon(note), color: linkColor(note), size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (note.pinned) ...[
                      Icon(
                        Icons.push_pin_rounded,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Expanded(
                      child: Text(
                        note.title.isEmpty ? 'من غير عنوان' : note.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                if (preview.isNotEmpty)
                  Text(
                    preview,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (showSubject && subject != null) SubjectChip(subject),
                    if (lecture != null)
                      Pill(
                        lecture.title,
                        color: theme.colorScheme.primary,
                        icon: Icons.menu_book_rounded,
                      ),
                    Text(
                      formatShortDate(note.updatedAt),
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (note.isLink)
            IconButton(
              tooltip: 'افتح اللينك',
              icon: const Icon(Icons.open_in_new_rounded),
              onPressed: () => openLink(context, note.url),
            ),
        ],
      ),
    );
  }
}

/// Adds or edits a note or a link.
class NoteForm extends StatefulWidget {
  const NoteForm({
    super.key,
    this.note,
    this.initialSubjectId,
    this.initialStudyItemId,
  });

  final Note? note;
  final String? initialSubjectId;
  final String? initialStudyItemId;

  @override
  State<NoteForm> createState() => _NoteFormState();
}

class _NoteFormState extends State<NoteForm> {
  final _formKey = GlobalKey<FormState>();
  late NoteKind _kind = widget.note?.kind ?? NoteKind.note;
  late final _title = TextEditingController(text: widget.note?.title);
  late final _url = TextEditingController(text: widget.note?.url);
  late final _body = TextEditingController(text: widget.note?.body);
  late String? _subjectId = widget.note?.subjectId ?? widget.initialSubjectId;
  late String? _studyItemId =
      widget.note?.studyItemId ?? widget.initialStudyItemId;
  late bool _pinned = widget.note?.pinned ?? false;

  @override
  void dispose() {
    _title.dispose();
    _url.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final now = DateTime.now();
    final old = widget.note;
    final url = _kind == NoteKind.link ? normalizeUrl(_url.text) : '';
    var title = _title.text.trim();
    if (title.isEmpty && url.isNotEmpty) {
      title = Uri.tryParse(url)?.host ?? url;
    }
    await context.read<AppStore>().saveNote(
      Note(
        id: old?.id ?? newId(),
        kind: _kind,
        subjectId: _subjectId,
        studyItemId: _subjectId == null ? null : _studyItemId,
        title: title,
        body: _body.text.trim(),
        url: url,
        pinned: _pinned,
        createdAt: old?.createdAt ?? now,
        updatedAt: now,
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    if (!await confirmDelete(context, 'تمسح دي؟')) return;
    if (!mounted) return;
    await context.read<AppStore>().deleteNote(widget.note!.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final editing = widget.note != null;
    final lectures = _subjectId == null
        ? const <StudyItem>[]
        : store.studyItemsFor(_subjectId!);
    final isLink = _kind == NoteKind.link;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'تعديل' : 'ملاحظة أو لينك'),
        actions: [
          if (editing && widget.note!.isLink)
            IconButton(
              tooltip: 'افتح اللينك',
              icon: const Icon(Icons.open_in_new_rounded),
              onPressed: () => openLink(context, widget.note!.url),
            ),
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
              SegmentedButton<NoteKind>(
                segments: const [
                  ButtonSegment(
                    value: NoteKind.note,
                    label: Text('ملاحظة'),
                    icon: Icon(Icons.sticky_note_2_rounded),
                  ),
                  ButtonSegment(
                    value: NoteKind.link,
                    label: Text('لينك'),
                    icon: Icon(Icons.link_rounded),
                  ),
                ],
                selected: {_kind},
                onSelectionChanged: (s) => setState(() => _kind = s.first),
              ),
              formGap,
              if (isLink) ...[
                TextFormField(
                  controller: _url,
                  autofocus: !editing,
                  keyboardType: TextInputType.url,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                    labelText: 'اللينك (درايف، يوتيوب، PDF…)',
                    prefixIcon: Icon(Icons.link_rounded),
                  ),
                  validator: (v) {
                    final t = v?.trim() ?? '';
                    if (t.isEmpty) return 'الصق اللينك';
                    final uri = Uri.tryParse(normalizeUrl(t));
                    if (uri == null || uri.host.isEmpty) {
                      return 'اللينك مش مظبوط';
                    }
                    return null;
                  },
                ),
                formGap,
              ],
              TextFormField(
                controller: _title,
                autofocus: !editing && !isLink,
                decoration: InputDecoration(
                  labelText: isLink ? 'اسمه (اختياري)' : 'العنوان',
                  prefixIcon: const Icon(Icons.title_rounded),
                ),
                validator: (v) => !isLink && (v == null || v.trim().isEmpty)
                    ? 'اكتب عنوان'
                    : null,
              ),
              formGap,
              TextFormField(
                controller: _body,
                minLines: isLink ? 2 : 6,
                maxLines: null,
                decoration: InputDecoration(
                  labelText: isLink ? 'وصف (اختياري)' : 'الملاحظة',
                  alignLabelWithHint: true,
                  prefixIcon: const Icon(Icons.notes),
                ),
              ),
              formGap,
              SubjectPicker(
                value: _subjectId,
                required: false,
                onChanged: (v) => setState(() {
                  _subjectId = v;
                  _studyItemId = null;
                }),
              ),
              if (lectures.isNotEmpty) ...[
                formGap,
                DropdownButtonFormField<String?>(
                  initialValue: lectures.any((l) => l.id == _studyItemId)
                      ? _studyItemId
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'محاضرة معينة (اختياري)',
                    prefixIcon: Icon(Icons.menu_book_rounded),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('المادة كلها'),
                    ),
                    for (final l in lectures)
                      DropdownMenuItem(value: l.id, child: Text(l.title)),
                  ],
                  onChanged: (v) => setState(() => _studyItemId = v),
                ),
              ],
              formGap,
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _pinned,
                onChanged: (v) => setState(() => _pinned = v),
                title: const Text('ثبّتها فوق'),
                secondary: const Icon(Icons.push_pin_outlined),
              ),
              const SizedBox(height: 16),
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
