import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/ids.dart';
import '../widgets/common.dart';
import '../widgets/subject_picker.dart';

/// Flashcard decks (one per subject), or one subject's cards.
class FlashcardsScreen extends StatelessWidget {
  const FlashcardsScreen({super.key, this.subjectId});

  final String? subjectId;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final now = DateTime.now();
    final subject = store.subjectById(subjectId);
    final due = store.dueCards(now, subjectId: subjectId);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(subject == null ? 'الفلاش كاردز' : 'كروت ${subject.name}'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'cards-fab',
        onPressed: () =>
            pushPage(context, FlashcardForm(initialSubjectId: subjectId)),
        icon: const Icon(Icons.add_rounded),
        label: const Text('كارت جديد'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
        children: [
          AppCard(
            gradient: AppColors.tealGradient,
            child: Row(
              children: [
                const Text('🧠', style: TextStyle(fontSize: 34)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        due.isEmpty
                            ? 'مفيش كروت للمراجعة النهارده'
                            : 'عندك ${countText(due.length, 'كارت', 'كارتين', 'كروت', 'كارت')} للمراجعة',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Text(
                        'كل كارت بيرجعلك بعد يوم، 3، أسبوع… على حسب '
                        'إنت فاكره ولا لأ',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (due.isNotEmpty)
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.teal,
                    ),
                    onPressed: () => pushPage(
                      context,
                      FlashcardReviewScreen(subjectId: subjectId),
                    ),
                    child: const Text('ابدأ'),
                  ),
              ],
            ),
          ),
          if (subjectId == null)
            ..._decks(context, store, now)
          else
            ..._cards(context, store, now, theme),
        ],
      ),
    );
  }

  List<Widget> _decks(BuildContext context, AppStore store, DateTime now) {
    final subjects = store.subjects
        .where((s) => store.cardsFor(s.id).isNotEmpty)
        .toList();
    final orphans = store.flashcards
        .where((c) => store.subjectById(c.subjectId) == null)
        .length;
    if (subjects.isEmpty && orphans == 0) {
      return const [
        EmptyState(
          icon: Icons.style_rounded,
          color: AppColors.teal,
          title: 'لسه مفيش كروت',
          message:
              'اكتب سؤال على وش الكارت والإجابة على ضهره، والتطبيق هيرجعهولك '
              'في الوقت المناسب عشان تثبّت المعلومة',
        ),
      ];
    }
    return [
      const SectionHeader('المواد', icon: Icons.layers_rounded),
      for (final s in subjects)
        _DeckTile(
          subject: s,
          total: store.cardsFor(s.id).length,
          due: store.dueCards(now, subjectId: s.id).length,
        ),
    ];
  }

  List<Widget> _cards(
    BuildContext context,
    AppStore store,
    DateTime now,
    ThemeData theme,
  ) {
    final cards = store.cardsFor(subjectId!);
    if (cards.isEmpty) {
      return const [
        EmptyState(
          icon: Icons.style_rounded,
          color: AppColors.teal,
          title: 'المادة دي لسه مفيهاش كروت',
        ),
      ];
    }
    return [
      SectionHeader(
        countText(cards.length, 'كارت واحد', 'كارتين', 'كروت', 'كارت'),
        icon: Icons.style_rounded,
      ),
      for (final c in cards)
        AppCard(
          onTap: () => pushPage(context, FlashcardForm(card: c)),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.front,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      c.back,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Pill(
                c.isNew
                    ? 'جديد'
                    : c.isDue(now)
                    ? 'النهارده'
                    : friendlyDay(c.dueDate!, now),
                color: c.isDue(now)
                    ? AppColors.teal
                    : theme.colorScheme.outline,
                icon: Icons.schedule_rounded,
              ),
            ],
          ),
        ),
    ];
  }
}

class _DeckTile extends StatelessWidget {
  const _DeckTile({
    required this.subject,
    required this.total,
    required this.due,
  });

  final Subject subject;
  final int total;
  final int due;

  @override
  Widget build(BuildContext context) {
    final color = Color(subject.colorValue);
    return AppCard(
      onTap: () => pushPage(context, FlashcardsScreen(subjectId: subject.id)),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          IconBadge(Icons.style_rounded, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject.name,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(
                  countText(total, 'كارت واحد', 'كارتين', 'كروت', 'كارت'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (due > 0)
            Pill(
              '$due للمراجعة',
              color: AppColors.teal,
              icon: Icons.bolt_rounded,
            ),
        ],
      ),
    );
  }
}

/// Adds or edits a card. "حفظ وكارت تاني" keeps the form open for the next.
class FlashcardForm extends StatefulWidget {
  const FlashcardForm({
    super.key,
    this.card,
    this.initialSubjectId,
    this.initialStudyItemId,
  });

  final Flashcard? card;
  final String? initialSubjectId;
  final String? initialStudyItemId;

  @override
  State<FlashcardForm> createState() => _FlashcardFormState();
}

class _FlashcardFormState extends State<FlashcardForm> {
  final _formKey = GlobalKey<FormState>();
  late final _front = TextEditingController(text: widget.card?.front);
  late final _back = TextEditingController(text: widget.card?.back);
  final _frontFocus = FocusNode();
  late String? _subjectId = widget.card?.subjectId ?? widget.initialSubjectId;
  late String? _studyItemId =
      widget.card?.studyItemId ?? widget.initialStudyItemId;

  @override
  void dispose() {
    _front.dispose();
    _back.dispose();
    _frontFocus.dispose();
    super.dispose();
  }

  Future<bool> _store() async {
    if (!_formKey.currentState!.validate()) return false;
    if (_subjectId == null) {
      showSnack(context, 'اختار المادة');
      return false;
    }
    final old = widget.card;
    final store = context.read<AppStore>();
    await store.saveCard(
      old == null
          ? Flashcard(
              id: newId(),
              subjectId: _subjectId!,
              studyItemId: _studyItemId,
              front: _front.text.trim(),
              back: _back.text.trim(),
              createdAt: DateTime.now(),
            )
          : old.edited(
              subjectId: _subjectId!,
              studyItemId: _studyItemId,
              front: _front.text.trim(),
              back: _back.text.trim(),
            ),
    );
    return true;
  }

  Future<void> _save() async {
    if (await _store() && mounted) Navigator.pop(context);
  }

  Future<void> _saveAndNext() async {
    if (!await _store() || !mounted) return;
    _front.clear();
    _back.clear();
    _frontFocus.requestFocus();
    showSnack(context, 'اتحفظ ✓ اكتب اللي بعده');
  }

  Future<void> _delete() async {
    if (!await confirmDelete(context, 'تمسح الكارت ده؟')) return;
    if (!mounted) return;
    await context.read<AppStore>().deleteCard(widget.card!.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final editing = widget.card != null;
    final lectures = _subjectId == null
        ? const <StudyItem>[]
        : store.studyItemsFor(_subjectId!);
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'تعديل الكارت' : 'كارت جديد'),
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
        child: ReadableWidth(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SubjectPicker(
                value: _subjectId,
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
                    labelText: 'من محاضرة (اختياري)',
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
              TextFormField(
                controller: _front,
                focusNode: _frontFocus,
                autofocus: !editing,
                minLines: 2,
                maxLines: null,
                decoration: const InputDecoration(
                  labelText: 'السؤال (وش الكارت)',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.help_outline_rounded),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'اكتب السؤال' : null,
              ),
              formGap,
              TextFormField(
                controller: _back,
                minLines: 3,
                maxLines: null,
                decoration: const InputDecoration(
                  labelText: 'الإجابة (ضهر الكارت)',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.lightbulb_outline_rounded),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'اكتب الإجابة' : null,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check),
                label: const Text('حفظ'),
              ),
              if (!editing) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _saveAndNext,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('حفظ وكارت تاني'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Goes through the due cards one by one: think, flip, say how it went.
class FlashcardReviewScreen extends StatefulWidget {
  const FlashcardReviewScreen({super.key, this.subjectId});

  final String? subjectId;

  @override
  State<FlashcardReviewScreen> createState() => _FlashcardReviewScreenState();
}

class _FlashcardReviewScreenState extends State<FlashcardReviewScreen> {
  late final List<String> _queue;
  bool _flipped = false;
  final Set<String> _reviewed = {};

  @override
  void initState() {
    super.initState();
    _queue = [
      for (final c in context.read<AppStore>().dueCards(
        DateTime.now(),
        subjectId: widget.subjectId,
      ))
        c.id,
    ];
  }

  void _answer(Flashcard card, CardAnswer a) {
    // Move on right away, so a quick second tap can't answer it twice.
    if (_queue.isEmpty || _queue.first != card.id) return;
    setState(() {
      _queue.removeAt(0);
      // Forgotten cards come back at the end of this session.
      if (a == CardAnswer.again) _queue.add(card.id);
      _flipped = false;
      _reviewed.add(card.id);
    });
    context.read<AppStore>().answerCard(card.id, a, DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final theme = Theme.of(context);
    Flashcard? card;
    while (_queue.isNotEmpty) {
      card = store.flashcards.where((c) => c.id == _queue.first).firstOrNull;
      if (card != null) break;
      _queue.removeAt(0);
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(card == null ? 'المراجعة' : 'فاضل ${_queue.length}'),
      ),
      body: card == null
          ? EmptyState(
              icon: Icons.celebration_rounded,
              color: AppColors.teal,
              title: _reviewed.isEmpty
                  ? 'مفيش كروت للمراجعة دلوقتي'
                  : 'برافو! راجعت ${countText(_reviewed.length, 'كارت', 'كارتين', 'كروت', 'كارت')} 🎉',
              message: 'هرجعلك بالكروت في ميعادها',
              action: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('تمام'),
              ),
            )
          : ReadableWidth(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SubjectChip(store.subjectById(card.subjectId)),
                    const SizedBox(height: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _flipped = !_flipped),
                        child: AppCard(
                          child: Center(
                            child: SingleChildScrollView(
                              child: Column(
                                children: [
                                  Text(
                                    card.front,
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.headlineSmall
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  if (_flipped) ...[
                                    const Divider(height: 40),
                                    Text(
                                      card.back,
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.titleLarge,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (!_flipped)
                      FilledButton.icon(
                        onPressed: () => setState(() => _flipped = true),
                        icon: const Icon(Icons.flip_rounded),
                        label: const Text('اقلب الكارت'),
                      )
                    else
                      Row(
                        children: [
                          for (final (a, label, color) in [
                            (CardAnswer.again, 'نسيتها', AppColors.danger),
                            (CardAnswer.hard, 'صعبة', AppColors.orange),
                            (CardAnswer.good, 'كويس', AppColors.teal),
                            (CardAnswer.easy, 'سهلة', AppColors.sky),
                          ]) ...[
                            if (a != CardAnswer.again) const SizedBox(width: 6),
                            Expanded(
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: color,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                ),
                                onPressed: () => _answer(card!, a),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(label),
                                    Text(
                                      _intervalLabel(card.intervalFor(a)),
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  static String _intervalLabel(int days) => days == 0
      ? 'تاني دلوقتي'
      : days == 1
      ? 'بكرة'
      : 'بعد ${daysText(days)}';
}
